#property copyright "Minimal SMC"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

input bool EnableTrading = false;
input bool TestMode = false;
input bool TestBuyDirection = true;
input double TestLot = 0.01;
input int TestStopLossPoints = 300;
input int TestTakeProfitPoints = 600;
input double RiskPercent = 0.5;
input double RewardRiskRatio = 2.0;
input int StopBufferPoints = 20;
input int DeviationPoints = 20;
input ulong MagicNumber = 140001;
input bool UseHigherTimeframeBias = false;
input ENUM_TIMEFRAMES BiasTimeframe = PERIOD_H4;
input int BiasLookbackBars = 500;

input int SwingLeftBars = 3;
input int SwingRightBars = 3;
input int IndicatorArrowOffsetPoints = 20;
input int OrderBlockLookbackBars = 20;
input int MaxBarsToScan = 500;
input int MaxActiveOrderBlocks = 3;
input int MaxActiveFvgs = 3;
input int MaxVisibleIdmLevels = 3;

CTrade Trade;
int IndicatorHandle = INVALID_HANDLE;
datetime LastSeenBarTime = 0;
bool TestTradeAttempted = false;

enum ENUM_MARKET_BIAS
{
   MARKET_BIAS_BEARISH = -1,
   MARKET_BIAS_NEUTRAL = 0,
   MARKET_BIAS_BULLISH = 1
};

int VolumeDigits(const double step)
{
   for(int digits = 0; digits <= 8; ++digits)
   {
      if(MathAbs(step - NormalizeDouble(step, digits)) < 1e-10)
         return digits;
   }
   return 8;
}

bool HasOpenPositionForThisEA()
{
   for(int index = PositionsTotal() - 1; index >= 0; --index)
   {
      ulong ticket = PositionGetTicket(index);
      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         return true;
   }
   return false;
}

double CalculateVolume(const ENUM_ORDER_TYPE orderType,
                       const double entryPrice,
                       const double stopLoss)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * RiskPercent / 100.0;
   if(equity <= 0.0 || riskMoney <= 0.0)
      return 0.0;

   double oneLotProfit = 0.0;
   if(!OrderCalcProfit(orderType, _Symbol, 1.0, entryPrice,
                       stopLoss, oneLotProfit))
   {
      PrintFormat("OrderCalcProfit failed. Error=%d", GetLastError());
      return 0.0;
   }

   double oneLotLoss = MathAbs(oneLotProfit);
   if(oneLotLoss <= 0.0)
      return 0.0;

   double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minimumVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maximumVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(volumeStep <= 0.0 || minimumVolume <= 0.0 || maximumVolume <= 0.0)
      return 0.0;

   double rawVolume = riskMoney / oneLotLoss;
   if(rawVolume < minimumVolume)
   {
      PrintFormat("Trade skipped: calculated lot %.8f is below minimum lot %.8f.",
                  rawVolume, minimumVolume);
      return 0.0;
   }

   double volume = MathMin(rawVolume, maximumVolume);
   volume = MathFloor(volume / volumeStep + 1e-9) * volumeStep;
   volume = NormalizeDouble(volume, VolumeDigits(volumeStep));
   if(volume < minimumVolume)
      return 0.0;

   return volume;
}

bool ReadClosedBarSignals(double &bullishSignal,
                           double &bearishSignal)
{
   double bufferValue[1];
   double values[4];

   for(int bufferIndex = 0; bufferIndex < 4; ++bufferIndex)
   {
      ResetLastError();
      if(CopyBuffer(IndicatorHandle, bufferIndex, 1, 1, bufferValue) != 1)
      {
         PrintFormat("CopyBuffer failed for buffer %d. Error=%d",
                     bufferIndex, GetLastError());
         return false;
      }
      values[bufferIndex] = bufferValue[0];
   }

   bool bullish = (values[0] != EMPTY_VALUE && values[0] != 0.0) ||
                 (values[2] != EMPTY_VALUE && values[2] != 0.0);
   bool bearish = (values[1] != EMPTY_VALUE && values[1] != 0.0) ||
                 (values[3] != EMPTY_VALUE && values[3] != 0.0);

   if(bullish && bearish)
   {
      Print("Trade skipped: both bullish and bearish signals on the same bar.");
      return false;
   }

   if(bullish || bearish)
   {
      PrintFormat("Closed-bar signal detected: %s, BOS buffer [0,1]=[%s,%s], CHoCH buffer [2,3]=[%s,%s].",
                  bullish ? "BULLISH" : "BEARISH",
                  values[0] == EMPTY_VALUE ? "empty" : DoubleToString(values[0], _Digits),
                  values[1] == EMPTY_VALUE ? "empty" : DoubleToString(values[1], _Digits),
                  values[2] == EMPTY_VALUE ? "empty" : DoubleToString(values[2], _Digits),
                  values[3] == EMPTY_VALUE ? "empty" : DoubleToString(values[3], _Digits));
   }

   bullishSignal = bullish ? 1.0 : 0.0;
   bearishSignal = bearish ? 1.0 : 0.0;
   return true;
}

bool CalculateHigherTimeframeBias(ENUM_MARKET_BIAS &bias)
{
   bias = MARKET_BIAS_NEUTRAL;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int requestedBars = (int)MathMax(BiasLookbackBars,
                                     SwingLeftBars + SwingRightBars + 20);
   ResetLastError();
   int copied = CopyRates(_Symbol, BiasTimeframe, 0, requestedBars, rates);
   if(copied <= SwingLeftBars + SwingRightBars + 5)
   {
      PrintFormat("HTF bias unavailable: only %d/%d bars copied for %s. Error=%d",
                  copied, requestedBars, EnumToString(BiasTimeframe), GetLastError());
      return false;
   }

   double previousSwingHigh = 0.0;
   double latestSwingHigh = 0.0;
   double previousSwingLow = 0.0;
   double latestSwingLow = 0.0;
   int swingHighCount = 0;
   int swingLowCount = 0;
   bool highAlreadyBroken = true;
   bool lowAlreadyBroken = true;
   int lastBreakDirection = 0;

   for(int bar = copied - SwingLeftBars - 1; bar >= 1; --bar)
   {
      if(bar + 1 < copied)
      {
         bool brokeHigh = swingHighCount > 0 && !highAlreadyBroken &&
                          rates[bar].close > latestSwingHigh &&
                          rates[bar + 1].close <= latestSwingHigh;
         bool brokeLow = swingLowCount > 0 && !lowAlreadyBroken &&
                         rates[bar].close < latestSwingLow &&
                         rates[bar + 1].close >= latestSwingLow;

         if(brokeHigh && brokeLow)
         {
            highAlreadyBroken = true;
            lowAlreadyBroken = true;
            lastBreakDirection = 0;
         }
         else if(brokeHigh)
         {
            highAlreadyBroken = true;
            lastBreakDirection = 1;
         }
         else if(brokeLow)
         {
            lowAlreadyBroken = true;
            lastBreakDirection = -1;
         }
      }

      int pivot = bar + SwingRightBars;
      if(pivot + SwingLeftBars >= copied)
         continue;

      bool isSwingHigh = true;
      bool isSwingLow = true;
      for(int offset = 1; offset <= SwingLeftBars; ++offset)
      {
         if(rates[pivot].high <= rates[pivot + offset].high)
            isSwingHigh = false;
         if(rates[pivot].low >= rates[pivot + offset].low)
            isSwingLow = false;
      }
      for(int offset = 1; offset <= SwingRightBars; ++offset)
      {
         if(rates[pivot].high <= rates[pivot - offset].high)
            isSwingHigh = false;
         if(rates[pivot].low >= rates[pivot - offset].low)
            isSwingLow = false;
      }

      if(isSwingHigh)
      {
         previousSwingHigh = latestSwingHigh;
         latestSwingHigh = rates[pivot].high;
         ++swingHighCount;
         highAlreadyBroken = false;
      }

      if(isSwingLow)
      {
         previousSwingLow = latestSwingLow;
         latestSwingLow = rates[pivot].low;
         ++swingLowCount;
         lowAlreadyBroken = false;
      }
   }

   if(swingHighCount < 2 || swingLowCount < 2)
   {
      PrintFormat("HTF bias is NEUTRAL: not enough confirmed swings on %s.",
                  EnumToString(BiasTimeframe));
      return true;
   }

   bool higherHighs = latestSwingHigh > previousSwingHigh;
   bool higherLows = latestSwingLow > previousSwingLow;
   bool lowerHighs = latestSwingHigh < previousSwingHigh;
   bool lowerLows = latestSwingLow < previousSwingLow;

   if(higherHighs && higherLows && lastBreakDirection > 0)
      bias = MARKET_BIAS_BULLISH;
   else if(lowerHighs && lowerLows && lastBreakDirection < 0)
      bias = MARKET_BIAS_BEARISH;

   return true;
}

bool StopsAreValid(const bool bullish,
                   const MqlTick &tick,
                   const double stopLoss,
                   const double takeProfit)
{
   double minimumDistance =
      (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

   if(bullish)
   {
      if(stopLoss >= tick.bid || takeProfit <= tick.bid)
         return false;
      if((tick.bid - stopLoss) < minimumDistance ||
         (takeProfit - tick.bid) < minimumDistance)
         return false;
   }
   else
   {
      if(stopLoss <= tick.ask || takeProfit >= tick.ask)
         return false;
      if((stopLoss - tick.ask) < minimumDistance ||
         (tick.ask - takeProfit) < minimumDistance)
         return false;
   }
   return true;
}

bool SendMarketOrder(const bool bullish,
                     const double volume,
                     const double stopLoss,
                     const double takeProfit,
                     const string comment)
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
   {
      PrintFormat("SymbolInfoTick failed. Error=%d", GetLastError());
      return false;
   }

   ENUM_ORDER_TYPE orderType = bullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double entryPrice = bullish ? tick.ask : tick.bid;
   if(!StopsAreValid(bullish, tick, stopLoss, takeProfit))
   {
      PrintFormat("Trade skipped: SL/TP violates broker minimum stop distance (%d points).",
                  (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL));
      return false;
   }

   ResetLastError();
   double requiredMargin = 0.0;
   if(!OrderCalcMargin(orderType, _Symbol, volume, entryPrice, requiredMargin))
   {
      PrintFormat("OrderCalcMargin failed. Error=%d", GetLastError());
      return false;
   }
   if(requiredMargin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
   {
      PrintFormat("Trade skipped: required margin %.2f exceeds free margin %.2f.",
                  requiredMargin, AccountInfoDouble(ACCOUNT_MARGIN_FREE));
      return false;
   }

   bool sent = bullish
               ? Trade.Buy(volume, _Symbol, 0.0, stopLoss, takeProfit, comment)
               : Trade.Sell(volume, _Symbol, 0.0, stopLoss, takeProfit, comment);

   uint retcode = Trade.ResultRetcode();
   if(!sent || (retcode != TRADE_RETCODE_DONE &&
                retcode != TRADE_RETCODE_DONE_PARTIAL &&
                retcode != TRADE_RETCODE_PLACED))
   {
      PrintFormat("Trade request failed. Retcode=%u, %s, error=%d",
                  retcode, Trade.ResultRetcodeDescription(), GetLastError());
      return false;
   }

   PrintFormat("%s order accepted. Volume=%.8f, entry=%.*f, SL=%.*f, TP=%.*f, retcode=%u",
               bullish ? "BUY" : "SELL", volume, _Digits, entryPrice,
               _Digits, stopLoss, _Digits, takeProfit, retcode);
   return true;
}

bool IsValidFixedTestLot(const double volume)
{
   double minimumVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maximumVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(volumeStep <= 0.0 || volume < minimumVolume || volume > maximumVolume)
   {
      PrintFormat("Test trade skipped: TestLot %.8f is outside symbol volume limits [%.8f, %.8f].",
                  volume, minimumVolume, maximumVolume);
      return false;
   }

   double stepCount = volume / volumeStep;
   if(MathAbs(stepCount - MathRound(stepCount)) > 1e-7)
   {
      PrintFormat("Test trade skipped: TestLot %.8f does not match volume step %.8f.",
                  volume, volumeStep);
      return false;
   }
   return true;
}

void ProcessTestTrade()
{
   TestTradeAttempted = true;
   if(HasOpenPositionForThisEA())
   {
      Print("Test trade skipped: this EA already has an open position for this symbol and magic number.");
      return;
   }

   if(!IsValidFixedTestLot(TestLot))
      return;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
   {
      PrintFormat("Test trade skipped: SymbolInfoTick failed. Error=%d", GetLastError());
      return;
   }

   bool bullish = TestBuyDirection;
   double entryPrice = bullish ? tick.ask : tick.bid;
   double stopLoss = bullish
                     ? entryPrice - TestStopLossPoints * _Point
                     : entryPrice + TestStopLossPoints * _Point;
   double takeProfit = bullish
                       ? entryPrice + TestTakeProfitPoints * _Point
                       : entryPrice - TestTakeProfitPoints * _Point;
   stopLoss = NormalizeDouble(stopLoss, _Digits);
   takeProfit = NormalizeDouble(takeProfit, _Digits);

   PrintFormat("TEST MODE: attempting one %s market order, lot=%.8f, SL=%d points, TP=%d points; SMC signals are ignored.",
               bullish ? "BUY" : "SELL", TestLot,
               TestStopLossPoints, TestTakeProfitPoints);
   SendMarketOrder(bullish, TestLot, stopLoss, takeProfit, "MinimalSMC test");
}

void ProcessClosedBar()
{
   if(HasOpenPositionForThisEA())
      return;

   double bullishSignal = 0.0;
   double bearishSignal = 0.0;
   if(!ReadClosedBarSignals(bullishSignal, bearishSignal))
      return;
   if(bullishSignal == 0.0 && bearishSignal == 0.0)
   {
      Print("No BOS/CHoCH signal on the just-closed candle; no trade.");
      return;
   }

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
   {
      PrintFormat("SymbolInfoTick failed. Error=%d", GetLastError());
      return;
   }

   double signalLow = iLow(_Symbol, _Period, 1);
   double signalHigh = iHigh(_Symbol, _Period, 1);
   if(signalLow <= 0.0 || signalHigh <= 0.0 || signalHigh <= signalLow)
   {
      Print("Trade skipped: invalid signal candle prices.");
      return;
   }

   bool bullish = bullishSignal > 0.0;
   if(UseHigherTimeframeBias)
   {
      ENUM_MARKET_BIAS bias = MARKET_BIAS_NEUTRAL;
      if(!CalculateHigherTimeframeBias(bias))
         return;

      string biasText = bias == MARKET_BIAS_BULLISH ? "BULLISH" :
                        bias == MARKET_BIAS_BEARISH ? "BEARISH" : "NEUTRAL";
      PrintFormat("%s signal checked against %s bias: %s.",
                  bullish ? "BUY" : "SELL", EnumToString(BiasTimeframe), biasText);

      if((bullish && bias != MARKET_BIAS_BULLISH) ||
         (!bullish && bias != MARKET_BIAS_BEARISH))
      {
         PrintFormat("Trade filtered: %s signal does not match %s HTF bias.",
                     bullish ? "BUY" : "SELL", biasText);
         return;
      }
   }

   ENUM_ORDER_TYPE orderType = bullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double entryPrice = bullish ? tick.ask : tick.bid;
   double stopLoss = bullish
                     ? signalLow - StopBufferPoints * _Point
                     : signalHigh + StopBufferPoints * _Point;
   stopLoss = NormalizeDouble(stopLoss, _Digits);

   double riskDistance = bullish
                         ? entryPrice - stopLoss
                         : stopLoss - entryPrice;
   if(riskDistance <= 0.0)
   {
      Print("Trade skipped: stop loss is on the wrong side of the entry.");
      return;
   }

   double takeProfit = bullish
                       ? entryPrice + riskDistance * RewardRiskRatio
                       : entryPrice - riskDistance * RewardRiskRatio;
   takeProfit = NormalizeDouble(takeProfit, _Digits);

   if(!StopsAreValid(bullish, tick, stopLoss, takeProfit))
   {
      PrintFormat("Trade skipped: SL/TP violates the broker minimum stop distance (%d points).",
                  (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL));
      return;
   }

   double volume = CalculateVolume(orderType, entryPrice, stopLoss);
   if(volume <= 0.0)
      return;

   SendMarketOrder(bullish, volume, stopLoss, takeProfit, "MinimalSMC");
}

int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER) &&
      AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO)
   {
      Print("MinimalSMC_EA is restricted to the Strategy Tester or a demo account.");
      return INIT_FAILED;
   }

   if(RiskPercent <= 0.0 || RiskPercent > 100.0 ||
      RewardRiskRatio <= 0.0 || StopBufferPoints < 0 ||
      TestLot <= 0.0 || TestStopLossPoints <= 0 || TestTakeProfitPoints <= 0 ||
      DeviationPoints < 0 || SwingLeftBars < 1 || SwingRightBars < 1 ||
      BiasLookbackBars < SwingLeftBars + SwingRightBars + 6 ||
      OrderBlockLookbackBars < 1 || MaxBarsToScan < 1 ||
      MaxActiveOrderBlocks < 0 || MaxActiveFvgs < 0 ||
      MaxVisibleIdmLevels < 0)
   {
      Print("Invalid EA input values.");
      return INIT_PARAMETERS_INCORRECT;
   }

   Trade.SetExpertMagicNumber(MagicNumber);
   Trade.SetDeviationInPoints((ulong)DeviationPoints);
   Trade.SetTypeFillingBySymbol(_Symbol);
   Trade.SetAsyncMode(false);

   if(!TestMode)
   {
      IndicatorHandle = iCustom(_Symbol, _Period, "MinimalSMC",
                                 SwingLeftBars, SwingRightBars,
                                 IndicatorArrowOffsetPoints,
                                 OrderBlockLookbackBars, MaxBarsToScan,
                                 MaxActiveOrderBlocks, MaxActiveFvgs,
                                 MaxVisibleIdmLevels);
      if(IndicatorHandle == INVALID_HANDLE)
      {
         PrintFormat("Cannot load MinimalSMC indicator. Install and compile MinimalSMC.mq5 under MQL5\\Indicators. Error=%d",
                     GetLastError());
         return INIT_FAILED;
      }
   }

   LastSeenBarTime = iTime(_Symbol, _Period, 0);
   PrintFormat("MinimalSMC_EA initialized on %s %s. EnableTrading=%s, TestMode=%s, risk=%.2f%%, RR=1:%.2f.",
               _Symbol, EnumToString(_Period),
               EnableTrading ? "true" : "false", TestMode ? "true" : "false",
               RiskPercent, RewardRiskRatio);
   if(TestMode)
      PrintFormat("TestMode will attempt exactly one %s trade on the first tick, ignoring SMC signals. TestLot=%.8f, SL=%d points, TP=%d points.",
                  TestBuyDirection ? "BUY" : "SELL", TestLot,
                  TestStopLossPoints, TestTakeProfitPoints);
   else
      Print("Signal mode waits for the next newly closed candle before checking BOS/CHoCH.");
   PrintFormat("Higher-timeframe bias filter: %s%s.",
               UseHigherTimeframeBias ? "ON (" : "OFF",
               UseHigherTimeframeBias ? EnumToString(BiasTimeframe) + ")" : "");
   if(!EnableTrading)
      Print("Trading is disabled by the EA input EnableTrading.");
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      Print("Trading is blocked: enable Algo Trading in the MT5 toolbar.");
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      Print("Trading is blocked: Allow Algo Trading is unchecked in EA properties.");
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      Print("Trading is blocked by the broker/account.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(IndicatorHandle != INVALID_HANDLE)
      IndicatorRelease(IndicatorHandle);
}

void OnTick()
{
   if(!EnableTrading)
      return;

   if(TestMode && !TestTradeAttempted)
   {
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
         !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
         !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
      {
         Print("Test trade blocked: check Algo Trading, EA properties, and account permissions.");
         TestTradeAttempted = true;
         return;
      }

      ProcessTestTrade();
      return;
   }

   if(TestMode)
      return;

   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime <= 0 || currentBarTime == LastSeenBarTime)
      return;

   LastSeenBarTime = currentBarTime;
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
      !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      Print("New bar detected, but trading permission is disabled (check Algo Trading, EA properties, and account permissions).");
      return;
   }

   if(IndicatorHandle == INVALID_HANDLE || BarsCalculated(IndicatorHandle) < 2)
   {
      Print("Indicator has not calculated enough bars yet.");
      return;
   }

   PrintFormat("Checking closed bar %s on %s %s.",
               TimeToString(iTime(_Symbol, _Period, 1), TIME_DATE|TIME_MINUTES),
               _Symbol, EnumToString(_Period));
   ProcessClosedBar();
}
