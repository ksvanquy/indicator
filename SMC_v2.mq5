// This work is licensed under CC BY-NC-SA 4.0:
// https://creativecommons.org/licenses/by-nc-sa/4.0/
// Derived from Smart Money Concepts [LuxAlgo] by LuxAlgo.
// Any redistribution must retain attribution and this license notice.
#property copyright "Derived from LuxAlgo - Smart Money Concepts"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_label1  "SMC trend candles"
#property indicator_color1  clrMediumSeaGreen,clrIndianRed

enum ENUM_SMC_MODE { SMC_HISTORICAL, SMC_PRESENT };
enum ENUM_SMC_STYLE { SMC_COLORED, SMC_MONOCHROME };
enum ENUM_SMC_FILTER { SMC_ATR, SMC_CUMULATIVE_RANGE };
enum ENUM_SMC_MITIGATION { SMC_CLOSE, SMC_HIGH_LOW };
enum ENUM_SMC_SHOW { SMC_ALL, SMC_BOS, SMC_CHOCH };
enum ENUM_SMC_LINE_STYLE { SMC_SOLID, SMC_DASHED, SMC_DOTTED };
enum ENUM_SMC_SIZE { SMC_TINY=8, SMC_SMALL=10, SMC_NORMAL=12 };

input group "Smart Money Concepts"
input ENUM_SMC_MODE Mode = SMC_HISTORICAL;
input ENUM_SMC_STYLE Style = SMC_COLORED;
input bool ColorCandles = false;
input int MaxBarsToProcess = 2000;

input group "Alerts"
input bool AlertInternalBullishBOS = false;
input bool AlertInternalBullishCHoCH = false;
input bool AlertInternalBearishBOS = false;
input bool AlertInternalBearishCHoCH = false;
input bool AlertSwingBullishBOS = false;
input bool AlertSwingBullishCHoCH = false;
input bool AlertSwingBearishBOS = false;
input bool AlertSwingBearishCHoCH = false;
input bool AlertInternalBullishOrderBlock = false;
input bool AlertInternalBearishOrderBlock = false;
input bool AlertSwingBullishOrderBlock = false;
input bool AlertSwingBearishOrderBlock = false;
input bool AlertEqualHighs = false;
input bool AlertEqualLows = false;
input bool AlertBullishFVG = false;
input bool AlertBearishFVG = false;

input group "Real Time Internal Structure"
input bool ShowInternalStructure = true;
input ENUM_SMC_SHOW InternalBullishStructure = SMC_ALL;
input color InternalBullishColor = C'8,153,129';
input ENUM_SMC_SHOW InternalBearishStructure = SMC_ALL;
input color InternalBearishColor = C'242,54,69';
input bool InternalConfluenceFilter = false;
input ENUM_SMC_SIZE InternalLabelSize = SMC_TINY;

input group "Real Time Swing Structure"
input bool ShowSwingStructure = true;
input ENUM_SMC_SHOW SwingBullishStructure = SMC_ALL;
input color SwingBullishColor = C'8,153,129';
input ENUM_SMC_SHOW SwingBearishStructure = SMC_ALL;
input color SwingBearishColor = C'242,54,69';
input ENUM_SMC_SIZE SwingLabelSize = SMC_SMALL;
input bool ShowSwingPoints = false;
input int SwingLength = 50;
input bool ShowStrongWeakHighLow = true;

input group "Order Blocks"
input bool ShowInternalOrderBlocks = true;
input int InternalOrderBlocksToShow = 5;
input bool ShowSwingOrderBlocks = false;
input int SwingOrderBlocksToShow = 5;
input ENUM_SMC_FILTER OrderBlockFilter = SMC_ATR;
input ENUM_SMC_MITIGATION OrderBlockMitigation = SMC_HIGH_LOW;
input color InternalBullishOBColor = C'49,121,245';
input color InternalBearishOBColor = C'247,124,128';
input color SwingBullishOBColor = C'24,72,204';
input color SwingBearishOBColor = C'178,40,51';

input group "EQH/EQL"
input bool ShowEqualHighsLows = true;
input int EqualHighLowConfirmationBars = 3;
input double EqualHighLowThreshold = 0.1;
input ENUM_SMC_SIZE EqualHighLowLabelSize = SMC_TINY;

input group "Fair Value Gaps"
input bool ShowFairValueGaps = false;
input bool FairValueGapAutoThreshold = true;
input ENUM_TIMEFRAMES FairValueGapTimeframe = PERIOD_CURRENT;
input color BullishFVGColor = C'0,255,104';
input color BearishFVGColor = C'255,0,8';
input int FairValueGapExtend = 1;

input group "Highs & Lows MTF"
input bool ShowDailyLevels = false;
input ENUM_SMC_LINE_STYLE DailyLevelsStyle = SMC_SOLID;
input color DailyLevelsColor = C'33,87,243';
input bool ShowWeeklyLevels = false;
input ENUM_SMC_LINE_STYLE WeeklyLevelsStyle = SMC_SOLID;
input color WeeklyLevelsColor = C'33,87,243';
input bool ShowMonthlyLevels = false;
input ENUM_SMC_LINE_STYLE MonthlyLevelsStyle = SMC_SOLID;
input color MonthlyLevelsColor = C'33,87,243';

input group "Premium & Discount Zones"
input bool ShowPremiumDiscountZones = false;
input color PremiumZoneColor = C'242,54,69';
input color EquilibriumZoneColor = C'135,139,148';
input color DiscountZoneColor = C'8,153,129';

input group "SMC Setup Overlay"
input bool ShowSetupOverlay = true;
input bool ShowSetupA = true;
input bool ShowSetupB = true;
input bool ShowSetupC = true;
input int SetupHistoryBars = 1000;
input int SetupMaxEventAgeBars = 96;
input color SetupAColor = clrDeepSkyBlue;
input color SetupBColor = clrGold;
input color SetupCColor = clrViolet;

double CandleOpen[], CandleHigh[], CandleLow[], CandleClose[], CandleColorIndex[];
double ParsedHighs[], ParsedLows[], AtrCache[], MeanRangeCache[], TrueRangeCache[];
string ObjectPrefix = "SMC_";
datetime LastProcessedBar = 0;
int LastRatesTotal = 0;
bool AlertsArmed = false;

struct PivotState
{
   double current;
   double previous;
   bool previousInitialized;
   bool crossed;
   datetime time;
   int index;
   bool initialized;
};

struct StructureDisplayState
{
   PivotState pivot;
   datetime rightTime;
   string id;
   string tag;
   color lineColor;
   bool internal;
   bool bullish;
   ENUM_SMC_SIZE labelSize;
   bool valid;
};

struct OrderBlockState
{
   double high;
   double low;
   datetime time;
   datetime created;
   int bias;
   bool internal;
};

struct FairValueGapState
{
   double top;
   double bottom;
   datetime time;
   int bias;
};

struct SetupZoneState
{
   double high;
   double low;
   datetime time;
   datetime created;
   bool valid;
};

struct SetupScanState
{
   int bias;
   double atr;
   int eventDirection;
   int eventKind;
   datetime eventTime;
   double eventLevel;
   double swingHigh;
   double swingLow;
   datetime swingHighTime;
   datetime swingLowTime;
   bool swingHighValid;
   bool swingLowValid;
   SetupZoneState bullishOb;
   SetupZoneState bearishOb;
   bool equalHighValid;
   bool equalLowValid;
   double equalHigh;
   double equalLow;
   datetime equalHighTime;
   datetime equalLowTime;
   datetime bullishSweepTime;
   datetime bearishSweepTime;
   double bullishSweepLow;
   double bearishSweepHigh;
};

PivotState SwingHigh, SwingLow, InternalHigh, InternalLow, EqualHigh, EqualLow;
PivotState TrailingTop, TrailingBottom;
datetime TrailingAnchorTime=0;
StructureDisplayState LatestStructures[4];
bool PresentStructuresDirty = false;
int SwingBias = 0, InternalBias = 0;
int SwingLeg = 0, InternalLeg = 0, EqualLeg = 0;
OrderBlockState OrderBlocks[];
FairValueGapState FairValueGaps[];
double CurrentFVGThreshold=0.0;
double CumulativeRangeClosedSum=0.0;
datetime SetupOverlayLastM5Bar=0;
bool SetupOverlayHistoryWarningLogged=false;

color BullColor(const bool internal)
{
   if(Style == SMC_MONOCHROME)
      return C'178,181,190';
   return internal ? InternalBullishColor : SwingBullishColor;
}

color BearColor(const bool internal)
{
   if(Style == SMC_MONOCHROME)
      return C'93,96,107';
   return internal ? InternalBearishColor : SwingBearishColor;
}

color WithAlpha(const color base,const uchar alpha)
{
   return (color)ColorToARGB(base,alpha);
}

ENUM_LINE_STYLE LineStyle(const ENUM_SMC_LINE_STYLE style)
{
   if(style == SMC_DASHED) return STYLE_DASH;
   if(style == SMC_DOTTED) return STYLE_DOT;
   return STYLE_SOLID;
}

void DeleteObjectsWithPrefix(const string prefix)
{
   for(int i=ObjectsTotal(0,-1,-1)-1;i>=0;--i)
   {
      string name=ObjectName(0,i,-1,-1);
      if(StringFind(name,prefix)==0)
         ObjectDelete(0,name);
   }
}

void DeleteSMCObjects()
{
   DeleteObjectsWithPrefix(ObjectPrefix);
}

void DrawText(const string name,const datetime when,const double price,
              const string text,const color textColor,const ENUM_ANCHOR_POINT anchor,
              const int fontSize=8)
{
   if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_TEXT,0,when,price))
      return;
   if(ObjectFind(0,name)>=0)
      ObjectMove(0,name,0,when,price);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontSize);
   ObjectSetInteger(0,name,OBJPROP_COLOR,textColor);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,anchor);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

void SendPopupAlert(const bool enabled,const string eventName)
{
   if(enabled && AlertsArmed)
      Alert("SMC: ",eventName," on ",_Symbol," ",EnumToString(_Period));
}

void DrawHorizontalStructure(const string id,const PivotState &pivot,
                             const datetime rightTime,const string tag,
                             const color lineColor,const bool internal,
                             const bool bullish,const ENUM_SMC_SIZE labelSize)
{
   if(Mode==SMC_PRESENT)
   {
      int slot=(internal ? 0 : 2)+(bullish ? 0 : 1);
      LatestStructures[slot].pivot=pivot;
      LatestStructures[slot].rightTime=rightTime;
      LatestStructures[slot].id=id;
      LatestStructures[slot].tag=tag;
      LatestStructures[slot].lineColor=lineColor;
      LatestStructures[slot].internal=internal;
      LatestStructures[slot].bullish=bullish;
      LatestStructures[slot].labelSize=labelSize;
      LatestStructures[slot].valid=true;
      PresentStructuresDirty=true;
      return;
   }
   string lineName=ObjectPrefix+"StructureLine_"+id;
   string labelName=ObjectPrefix+"StructureLabel_"+id;
   if(!ObjectCreate(0,lineName,OBJ_TREND,0,pivot.time,pivot.current,rightTime,pivot.current))
      return;
   ObjectSetInteger(0,lineName,OBJPROP_COLOR,lineColor);
   ObjectSetInteger(0,lineName,OBJPROP_STYLE,internal ? STYLE_DASH : STYLE_SOLID);
   ObjectSetInteger(0,lineName,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,lineName,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,lineName,OBJPROP_SELECTABLE,false);
   datetime middle=pivot.time+(rightTime-pivot.time)/2;
   DrawText(labelName,middle,pivot.current,tag,lineColor,
            bullish ? ANCHOR_UPPER : ANCHOR_LOWER,(int)labelSize);
}

void RenderPresentStructures()
{
   if(Mode!=SMC_PRESENT || !PresentStructuresDirty)
      return;
   DeleteObjectsWithPrefix(ObjectPrefix+"StructureLine_");
   DeleteObjectsWithPrefix(ObjectPrefix+"StructureLabel_");
   for(int i=0;i<ArraySize(LatestStructures);i++)
   {
      if(!LatestStructures[i].valid)
         continue;
      string lineName=ObjectPrefix+"StructureLine_"+LatestStructures[i].id;
      string labelName=ObjectPrefix+"StructureLabel_"+LatestStructures[i].id;
      PivotState pivot=LatestStructures[i].pivot;
      datetime rightTime=LatestStructures[i].rightTime;
      if(!ObjectCreate(0,lineName,OBJ_TREND,0,pivot.time,pivot.current,
                       rightTime,pivot.current))
         continue;
      ObjectSetInteger(0,lineName,OBJPROP_COLOR,LatestStructures[i].lineColor);
      ObjectSetInteger(0,lineName,OBJPROP_STYLE,
                       LatestStructures[i].internal ? STYLE_DASH : STYLE_SOLID);
      ObjectSetInteger(0,lineName,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,lineName,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,lineName,OBJPROP_SELECTABLE,false);
      datetime middle=pivot.time+(rightTime-pivot.time)/2;
      DrawText(labelName,middle,pivot.current,LatestStructures[i].tag,
               LatestStructures[i].lineColor,
               LatestStructures[i].bullish ? ANCHOR_UPPER : ANCHOR_LOWER,
               (int)LatestStructures[i].labelSize);
   }
   PresentStructuresDirty=false;
}

void ExtendPresentStructures(const datetime rightTime)
{
   if(Mode!=SMC_PRESENT || PresentStructuresDirty)
      return;
   for(int i=0;i<ArraySize(LatestStructures);i++)
   {
      if(!LatestStructures[i].valid)
         continue;
      LatestStructures[i].rightTime=rightTime;
      string lineName=ObjectPrefix+"StructureLine_"+LatestStructures[i].id;
      string labelName=ObjectPrefix+"StructureLabel_"+LatestStructures[i].id;
      PivotState pivot=LatestStructures[i].pivot;
      if(ObjectFind(0,lineName)>=0)
      {
         ObjectMove(0,lineName,0,pivot.time,pivot.current);
         ObjectMove(0,lineName,1,rightTime,pivot.current);
      }
      if(ObjectFind(0,labelName)>=0)
      {
         datetime middle=pivot.time+(rightTime-pivot.time)/2;
         ObjectMove(0,labelName,0,middle,pivot.current);
      }
   }
}

void DrawZoneBox(const string name,const datetime startTime,const datetime endTime,
                 const double top,const double bottom,const color zoneColor)
{
   if(ObjectFind(0,name)<0 &&
      !ObjectCreate(0,name,OBJ_RECTANGLE,0,startTime,top,endTime,bottom))
      return;
   ObjectMove(0,name,0,startTime,top);
   ObjectMove(0,name,1,endTime,bottom);
   ObjectSetInteger(0,name,OBJPROP_COLOR,zoneColor);
   ObjectSetInteger(0,name,OBJPROP_FILL,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
}

double SetupAtr(const MqlRates &rates[],const int ratesTotal,const int index)
{
   double sum=0.0;
   int samples=0;
   int end=MathMin(ratesTotal-1,index+14);
   for(int bar=index;bar<end;bar++)
   {
      double previousClose=rates[bar+1].close;
      double trueRange=MathMax(rates[bar].high-rates[bar].low,
                        MathMax(MathAbs(rates[bar].high-previousClose),
                                MathAbs(rates[bar].low-previousClose)));
      sum+=trueRange;
      samples++;
   }
   return samples>0 ? sum/samples : 0.0;
}

void StoreSetupOb(const MqlRates &rates[],
                  const int pivotIndex,
                  const int currentIndex,
                  const bool bullish,
                  SetupZoneState &zone)
{
   for(int bar=currentIndex+1;bar<=pivotIndex;bar++)
   {
      bool opposingCandle=(bullish ? rates[bar].close<rates[bar].open :
                                     rates[bar].close>rates[bar].open);
      if(!opposingCandle)
         continue;

      zone.high=rates[bar].high;
      zone.low=rates[bar].low;
      zone.time=rates[bar].time;
      zone.created=rates[currentIndex].time;
      zone.valid=true;
      return;
   }
   zone.valid=false;
}

bool AnalyzeSetupStructure(const MqlRates &rates[],
                           const int ratesTotal,
                           const int legSize,
                           SetupScanState &state)
{
   ZeroMemory(state);
   if(legSize<1 || ratesTotal<legSize*2+5)
      return false;

   int legState=0;
   int pivotHighIndex=-1;
   int pivotLowIndex=-1;
   bool pivotHighValid=false;
   bool pivotLowValid=false;
   bool previousHighValid=false;
   bool previousLowValid=false;
   double pivotHigh=0.0;
   double pivotLow=0.0;
   double previousHigh=0.0;
   double previousLow=0.0;
   bool highCrossed=false;
   bool lowCrossed=false;

   for(int i=ratesTotal-legSize-1;i>=1;i--)
   {
      if(state.bullishOb.valid &&
         rates[i].time>state.bullishOb.created &&
         rates[i].close<state.bullishOb.low)
         state.bullishOb.valid=false;
      if(state.bearishOb.valid &&
         rates[i].time>state.bearishOb.created &&
         rates[i].close>state.bearishOb.high)
         state.bearishOb.valid=false;

      int candidate=i+legSize;
      if(candidate>=ratesTotal)
         continue;

      double priorHigh=-DBL_MAX;
      double priorLow=DBL_MAX;
      for(int bar=i;bar<candidate;bar++)
      {
         priorHigh=MathMax(priorHigh,rates[bar].high);
         priorLow=MathMin(priorLow,rates[bar].low);
      }

      int nextLeg=legState;
      if(rates[candidate].high>priorHigh)
         nextLeg=0;
      else if(rates[candidate].low<priorLow)
         nextLeg=1;

      if(nextLeg!=legState)
      {
         double atr=SetupAtr(rates,ratesTotal,i);
         if((nextLeg-legState)==1)
         {
            if(previousLowValid && atr>0.0 &&
               MathAbs(previousLow-rates[candidate].low)<=
               EqualHighLowThreshold*atr)
            {
               state.equalLowValid=true;
               state.equalLow=(previousLow+rates[candidate].low)*0.5;
               state.equalLowTime=rates[candidate].time;
            }
            previousLow=rates[candidate].low;
            previousLowValid=true;
            pivotLow=rates[candidate].low;
            pivotLowIndex=candidate;
            pivotLowValid=true;
            lowCrossed=false;
            state.swingLow=pivotLow;
            state.swingLowTime=rates[candidate].time;
            state.swingLowValid=true;
         }
         else
         {
            if(previousHighValid && atr>0.0 &&
               MathAbs(previousHigh-rates[candidate].high)<=
               EqualHighLowThreshold*atr)
            {
               state.equalHighValid=true;
               state.equalHigh=(previousHigh+rates[candidate].high)*0.5;
               state.equalHighTime=rates[candidate].time;
            }
            previousHigh=rates[candidate].high;
            previousHighValid=true;
            pivotHigh=rates[candidate].high;
            pivotHighIndex=candidate;
            pivotHighValid=true;
            highCrossed=false;
            state.swingHigh=pivotHigh;
            state.swingHighTime=rates[candidate].time;
            state.swingHighValid=true;
         }
         legState=nextLeg;
      }

      if(state.equalLowValid &&
         rates[i].low<state.equalLow && rates[i].close>state.equalLow)
      {
         state.bullishSweepTime=rates[i].time+PeriodSeconds(PERIOD_M15);
         state.bullishSweepLow=rates[i].low;
      }
      if(state.equalHighValid &&
         rates[i].high>state.equalHigh && rates[i].close<state.equalHigh)
      {
         state.bearishSweepTime=rates[i].time+PeriodSeconds(PERIOD_M15);
         state.bearishSweepHigh=rates[i].high;
      }

      bool bullish=(pivotHighValid && !highCrossed &&
                    rates[i].close>pivotHigh &&
                    rates[i+1].close<=pivotHigh);
      bool bearish=(pivotLowValid && !lowCrossed &&
                    rates[i].close<pivotLow &&
                    rates[i+1].close>=pivotLow);

      if(bullish)
      {
         state.eventDirection=1;
         state.eventKind=(state.bias<0 ? 2 : 1);
         state.eventTime=rates[i].time;
         state.eventLevel=pivotHigh;
         highCrossed=true;
         state.bias=1;
         StoreSetupOb(rates,pivotHighIndex,i,true,state.bullishOb);
      }
      if(bearish)
      {
         state.eventDirection=-1;
         state.eventKind=(state.bias>0 ? 2 : 1);
         state.eventTime=rates[i].time;
         state.eventLevel=pivotLow;
         lowCrossed=true;
         state.bias=-1;
         StoreSetupOb(rates,pivotLowIndex,i,false,state.bearishOb);
      }
   }
   state.atr=SetupAtr(rates,ratesTotal,1);
   return true;
}

bool SetupZoneRetested(const MqlRates &bar,const SetupZoneState &zone)
{
   return zone.valid && bar.low<=zone.high && bar.high>=zone.low;
}

bool SetupRejection(const MqlRates &bar,
                    const SetupZoneState &zone,
                    const bool bullish)
{
   if(!SetupZoneRetested(bar,zone))
      return false;
   double body=MathAbs(bar.close-bar.open);
   if(body<=0.0)
      return false;
   if(bullish)
   {
      double lowerWick=MathMin(bar.open,bar.close)-bar.low;
      return bar.close>bar.open && bar.close>zone.high &&
             lowerWick>=0.5*body;
   }
   double upperWick=bar.high-MathMax(bar.open,bar.close);
   return bar.close<bar.open && bar.close<zone.low &&
          upperWick>=0.5*body;
}

void SetSetupPanelLabel(const string name,
                        const string text,
                        const int y,
                        const color textColor)
{
   if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_LABEL,0,0,0))
   {
      PrintFormat("SMC: could not create setup overlay label %s (error=%d).",
                  name,GetLastError());
      return;
   }
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,18);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,10);
   ObjectSetInteger(0,name,OBJPROP_COLOR,textColor);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,10);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
}

string EvaluateSetupAB(const bool reversal,
                       const SetupScanState &h1,
                       const SetupScanState &m15,
                       const MqlRates &lastM5,
                       const datetime latestM15Close,
                       int &direction,
                       SetupZoneState &displayZone)
{
   direction=0;
   bool eventMatches=(reversal ? m15.eventKind==2 : m15.eventKind==1);
   if(!eventMatches)
      return reversal ? "Cho Swing CHoCH M15" : "Cho BOS M15";
   if(latestM15Close<m15.eventTime ||
      latestM15Close-m15.eventTime>
      (datetime)(SetupMaxEventAgeBars*PeriodSeconds(PERIOD_M15)))
      return "Setup het han";

   direction=m15.eventDirection;
   if(reversal && h1.bias!=-direction)
      return "Cho Swing bias H1 nguoc huong";
   if(!reversal && (h1.bias!=direction ||
      m15.bias!=direction))
      return "Bias H1/M15 chua cung huong";

   SetupZoneState zone=(direction>0 ? m15.bullishOb : m15.bearishOb);
   if(!zone.valid)
      return "Khong co OB hop le";
   double atr=m15.atr;
   if(atr<=0.0 || zone.high-zone.low>1.5*atr)
      return "OB rong hon 1.5 ATR M15";

   displayZone=zone;
   if(SetupRejection(lastM5,zone,direction>0))
      return "DA XAC NHAN - tu danh gia";
   if(SetupZoneRetested(lastM5,zone))
      return "Da hoi OB - cho nen tu choi M5";
   return "Cho gia hoi ve OB";
}

string EvaluateSetupC(const SetupScanState &m15,
                      const SetupScanState &m5,
                      const datetime lastM5Close,
                      int &direction)
{
   direction=0;
   datetime sweepTime=0;
   if(m15.bullishSweepTime>0 &&
      lastM5Close>=m15.bullishSweepTime &&
      lastM5Close<=m15.bullishSweepTime+3*PeriodSeconds(PERIOD_M5))
   {
      direction=1;
      sweepTime=m15.bullishSweepTime;
   }
   else if(m15.bearishSweepTime>0 &&
           lastM5Close>=m15.bearishSweepTime &&
           lastM5Close<=m15.bearishSweepTime+3*PeriodSeconds(PERIOD_M5))
   {
      direction=-1;
      sweepTime=m15.bearishSweepTime;
   }
   else
   {
      if((m15.bullishSweepTime>0 &&
          lastM5Close>m15.bullishSweepTime+
                      3*PeriodSeconds(PERIOD_M5)) ||
         (m15.bearishSweepTime>0 &&
          lastM5Close>m15.bearishSweepTime+
                      3*PeriodSeconds(PERIOD_M5)))
         return "Sweep EQH/EQL da het han";
      return "Cho sweep EQH/EQL M15";
   }

   bool confirmed=(m5.eventKind==2 && m5.eventDirection==direction &&
                m5.eventTime>=sweepTime);
   if(confirmed)
      return "DA XAC NHAN - tu danh gia";
   return "Da sweep - cho CHoCH M5";
}

void DrawSetupZone(const string id,
                   const SetupZoneState &zone,
                   const color zoneColor,
                   const datetime chartTime)
{
   string name=ObjectPrefix+"Setup_Zone_"+id;
   string labelName=name+"_Label";
   if(!zone.valid)
   {
      ObjectDelete(0,name);
      ObjectDelete(0,labelName);
      return;
   }
   int seconds=PeriodSeconds(_Period);
   if(seconds<=0)
      seconds=60;
   DrawZoneBox(name,zone.time,chartTime+seconds*40,zone.high,zone.low,
               WithAlpha(zoneColor,55));
   DrawText(labelName,zone.time,zone.high,id+" OB",zoneColor,
            ANCHOR_LOWER,8);
}

void DrawSetupSignalMarker(const string setupId,
                           const MqlRates &bar,
                           const int direction,
                           const color markerColor)
{
   string name=ObjectPrefix+"Setup_Signal_"+setupId;
   double offset=SymbolInfoDouble(_Symbol,SYMBOL_POINT)*10.0;
   double price=(direction>0 ? bar.low-offset : bar.high+offset);
   if(ObjectFind(0,name)<0 &&
      !ObjectCreate(0,name,OBJ_ARROW,0,bar.time,price))
   {
      PrintFormat("SMC: could not create setup signal marker %s (error=%d).",
                  name,GetLastError());
      return;
   }
   ObjectMove(0,name,0,bar.time,price);
   ObjectSetInteger(0,name,OBJPROP_ARROWCODE,direction>0 ? 233 : 234);
   ObjectSetInteger(0,name,OBJPROP_COLOR,markerColor);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

void DrawSetupPriceLine(const string setupId,
                        const string levelId,
                        const datetime startTime,
                        const double price,
                        const string label,
                        const color lineColor)
{
   string name=ObjectPrefix+"Setup_Risk_"+setupId+"_"+levelId;
   if(ObjectFind(0,name)<0 &&
      !ObjectCreate(0,name,OBJ_HLINE,0,0,price))
   {
      PrintFormat("SMC: could not create setup reference %s (error=%d).",
                  name,GetLastError());
      return;
   }
   ObjectMove(0,name,0,0,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,lineColor);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,3);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,
                   label+" "+DoubleToString(price,_Digits));

   int seconds=PeriodSeconds(_Period);
   if(seconds<=0)
      seconds=60;
   datetime labelTime=startTime+seconds*3;
   DrawText(name+"_Label",labelTime,price,
            setupId+" "+label+"  "+DoubleToString(price,_Digits),
            lineColor,ANCHOR_LEFT,10);
}

void DrawSetupRiskReferences(const string setupId,
                             const MqlRates &signalBar,
                             const int direction,
                             const double stopPrice,
                             const color setupColor)
{
   double entryPrice=signalBar.close;
   double risk=MathAbs(entryPrice-stopPrice);
   if(risk<=0.0)
      return;
   double targetPrice=entryPrice+direction*2.0*risk;
   DrawSetupPriceLine(setupId,"Entry",signalBar.time,entryPrice,
                      "ENTRY (M5 close)",clrWhite);
   DrawSetupPriceLine(setupId,"SL",signalBar.time,stopPrice,
                      "SL",clrTomato);
   DrawSetupPriceLine(setupId,"2R",signalBar.time,targetPrice,
                      "TP (2R)",setupColor);
}

void DeleteSetupRiskReferences(const string setupId)
{
   string prefix=ObjectPrefix+"Setup_Risk_"+setupId+"_";
   DeleteObjectsWithPrefix(prefix);
}

void RefreshSetupOverlay()
{
   if(!ShowSetupOverlay)
   {
      DeleteObjectsWithPrefix(ObjectPrefix+"Setup_");
      SetupOverlayLastM5Bar=0;
      return;
   }

   datetime currentM5Bar=iTime(_Symbol,PERIOD_M5,0);
   if(currentM5Bar<=0 || currentM5Bar==SetupOverlayLastM5Bar)
      return;

   MqlRates h1Rates[],m15Rates[],m5Rates[];
   ArraySetAsSeries(h1Rates,true);
   ArraySetAsSeries(m15Rates,true);
   ArraySetAsSeries(m5Rates,true);
   int history=MathMax(SetupHistoryBars,100);
   ResetLastError();
   int h1Copied=CopyRates(_Symbol,PERIOD_H1,0,history,h1Rates);
   int h1Error=GetLastError();
   ResetLastError();
   int m15Copied=CopyRates(_Symbol,PERIOD_M15,0,history,m15Rates);
   int m15Error=GetLastError();
   ResetLastError();
   int m5Copied=CopyRates(_Symbol,PERIOD_M5,0,history,m5Rates);
   int m5Error=GetLastError();
   if(h1Copied<=0 || m15Copied<=0 || m5Copied<3)
   {
      if(!SetupOverlayHistoryWarningLogged)
      {
         PrintFormat("SMC setup overlay is waiting for MT5 history synchronization. "
                     "CopyRates H1=%d (error=%d), M15=%d (error=%d), "
                     "M5=%d (error=%d). It will retry automatically.",
                     h1Copied,h1Error,m15Copied,m15Error,m5Copied,m5Error);
         SetupOverlayHistoryWarningLogged=true;
      }
      return;
   }

   SetupScanState h1State,m15SwingState,m15InternalState,m5State;
   bool h1Ready=AnalyzeSetupStructure(h1Rates,h1Copied,SwingLength,h1State);
   bool m15SwingReady=AnalyzeSetupStructure(m15Rates,m15Copied,SwingLength,
                                             m15SwingState);
   bool m15InternalReady=AnalyzeSetupStructure(m15Rates,m15Copied,5,
                                                m15InternalState);
   bool m5Ready=AnalyzeSetupStructure(m5Rates,m5Copied,5,m5State);
   if(!h1Ready || !m15SwingReady || !m15InternalReady || !m5Ready)
   {
      if(!SetupOverlayHistoryWarningLogged)
      {
         Print("SMC setup overlay is waiting for more H1/M15/M5 bars to confirm pivots.");
         SetupOverlayHistoryWarningLogged=true;
      }
      return;
   }
   MqlRates lastM5=m5Rates[1];
   datetime lastM5Close=lastM5.time+PeriodSeconds(PERIOD_M5);
   datetime latestM15Close=m15Rates[1].time+PeriodSeconds(PERIOD_M15);

   string panel=ObjectPrefix+"Setup_Panel";
   if(ObjectFind(0,panel)<0 && !ObjectCreate(0,panel,OBJ_RECTANGLE_LABEL,0,0,0))
   {
      PrintFormat("SMC: could not create setup overlay panel (error=%d).",
                  GetLastError());
      return;
   }
   SetupOverlayLastM5Bar=currentM5Bar;
   SetupOverlayHistoryWarningLogged=false;
   ObjectSetInteger(0,panel,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,panel,OBJPROP_XDISTANCE,8);
   ObjectSetInteger(0,panel,OBJPROP_YDISTANCE,8);
   ObjectSetInteger(0,panel,OBJPROP_XSIZE,560);
   ObjectSetInteger(0,panel,OBJPROP_YSIZE,150);
   ObjectSetInteger(0,panel,OBJPROP_BGCOLOR,C'20,20,20');
   ObjectSetInteger(0,panel,OBJPROP_BORDER_COLOR,clrDimGray);
   ObjectSetInteger(0,panel,OBJPROP_BACK,false);
   ObjectSetInteger(0,panel,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,panel,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,panel,OBJPROP_ZORDER,1);

   SetSetupPanelLabel(ObjectPrefix+"Setup_Title",
                      "SMC SETUP - ENTRY / SL / TP CHI KHI XAC NHAN",16,clrWhite);
   SetSetupPanelLabel(ObjectPrefix+"Setup_Timeframes",
                      "Khung H1 / M15 / M5 | chi dung nen da dong",36,clrSilver);
   int row=60;
   if(ShowSetupA)
   {
      int direction=0;
      SetupZoneState zone;
      ZeroMemory(zone);
      string status=EvaluateSetupAB(true,h1State,m15SwingState,lastM5,
                                    latestM15Close,direction,zone);
      string side=(direction>0 ? " | MUA | " :
                   direction<0 ? " | BAN | " : " | ");
      SetSetupPanelLabel(ObjectPrefix+"Setup_A","A Dao chieu"+side+status,row,
                         direction>0 ? SetupAColor :
                         direction<0 ? BearColor(false) : clrSilver);
      DrawSetupZone("A",zone,SetupAColor,iTime(_Symbol,_Period,0));
      if(StringFind(status,"DA XAC NHAN")==0)
      {
         DrawSetupSignalMarker("A",lastM5,direction,SetupAColor);
         double stopPrice=(direction>0 ?
                           zone.low-0.1*m15SwingState.atr :
                           zone.high+0.1*m15SwingState.atr);
         DrawSetupRiskReferences("A",lastM5,direction,stopPrice,SetupAColor);
      }
      row+=24;
   }
   else
   {
      ObjectDelete(0,ObjectPrefix+"Setup_A");
      ObjectDelete(0,ObjectPrefix+"Setup_Zone_A");
      ObjectDelete(0,ObjectPrefix+"Setup_Signal_A");
      DeleteSetupRiskReferences("A");
   }
   if(ShowSetupB)
   {
      int direction=0;
      SetupZoneState zone;
      ZeroMemory(zone);
      string status=EvaluateSetupAB(false,h1State,m15InternalState,lastM5,
                                    latestM15Close,direction,zone);
      string side=(direction>0 ? " | MUA | " :
                   direction<0 ? " | BAN | " : " | ");
      SetSetupPanelLabel(ObjectPrefix+"Setup_B","B Tiep dien"+side+status,row,
                         direction>0 ? SetupBColor :
                         direction<0 ? BearColor(false) : clrSilver);
      DrawSetupZone("B",zone,SetupBColor,iTime(_Symbol,_Period,0));
      if(StringFind(status,"DA XAC NHAN")==0)
      {
         DrawSetupSignalMarker("B",lastM5,direction,SetupBColor);
         double stopPrice=(direction>0 ?
                           zone.low-0.1*m15InternalState.atr :
                           zone.high+0.1*m15InternalState.atr);
         DrawSetupRiskReferences("B",lastM5,direction,stopPrice,SetupBColor);
      }
      row+=24;
   }
   else
   {
      ObjectDelete(0,ObjectPrefix+"Setup_B");
      ObjectDelete(0,ObjectPrefix+"Setup_Zone_B");
      ObjectDelete(0,ObjectPrefix+"Setup_Signal_B");
      DeleteSetupRiskReferences("B");
   }
   if(ShowSetupC)
   {
      int direction=0;
      string status=EvaluateSetupC(m15InternalState,m5State,lastM5Close,
                                   direction);
      string side=(direction>0 ? " | MUA | " :
                   direction<0 ? " | BAN | " : " | ");
      SetSetupPanelLabel(ObjectPrefix+"Setup_C","C Quet thanh khoan"+side+status,
                         row,
                         direction>0 ? SetupCColor :
                         direction<0 ? BearColor(false) : clrSilver);
      if(StringFind(status,"DA XAC NHAN")==0)
      {
         MqlRates signalM5=lastM5;
         for(int bar=1;bar<m5Copied;bar++)
         {
            if(m5Rates[bar].time==m5State.eventTime)
            {
               signalM5=m5Rates[bar];
               break;
            }
         }
         DrawSetupSignalMarker("C",signalM5,direction,SetupCColor);
         double sweepExtreme=(direction>0 ?
                              m15InternalState.bullishSweepLow :
                              m15InternalState.bearishSweepHigh);
         double stopPrice=(direction>0 ?
                           sweepExtreme-0.1*m15InternalState.atr :
                           sweepExtreme+0.1*m15InternalState.atr);
         DrawSetupRiskReferences("C",signalM5,direction,stopPrice,SetupCColor);
      }
   }
   else
   {
      ObjectDelete(0,ObjectPrefix+"Setup_C");
      ObjectDelete(0,ObjectPrefix+"Setup_Signal_C");
      ObjectDelete(0,ObjectPrefix+"Setup_Timeframes");
      DeleteSetupRiskReferences("C");
   }
   ChartRedraw(0);
}

bool IsStructureVisible(const bool internal,const bool bullish,const string tag)
{
   if(internal && !ShowInternalStructure) return false;
   if(!internal && !ShowSwingStructure) return false;
   ENUM_SMC_SHOW filter;
   if(internal)
      filter=bullish ? InternalBullishStructure : InternalBearishStructure;
   else
      filter=bullish ? SwingBullishStructure : SwingBearishStructure;
   if(filter==SMC_ALL) return true;
   if(filter==SMC_BOS) return tag=="BOS";
   return tag=="CHoCH";
}

void StoreOrderBlock(const PivotState &pivot,const bool internal,const int bias,
                     const datetime &time[],
                     const int rates_total,const int currentIndex)
{
   if((internal && !ShowInternalOrderBlocks) || (!internal && !ShowSwingOrderBlocks))
      return;
   int oldest=currentIndex+1;
   int newest=pivot.index;
   if(oldest<0 || newest<oldest || newest>=rates_total ||
      newest>=ArraySize(ParsedHighs)) return;
   double extreme=(bias<0 ? -DBL_MAX : DBL_MAX);
   int selected=newest;
   for(int i=newest;i>=oldest;i--)
   {
      double value=(bias<0 ? ParsedHighs[i] : ParsedLows[i]);
      if((bias<0 && value>extreme) || (bias>0 && value<extreme))
      {
         extreme=value;
         selected=i;
      }
   }
   OrderBlockState block;
   block.high=ParsedHighs[selected];
   block.low=ParsedLows[selected];
   block.time=time[selected];
   block.created=time[currentIndex];
   block.bias=bias;
   block.internal=internal;
   int count=ArraySize(OrderBlocks);
   if(ArrayResize(OrderBlocks,count+1)!=count+1)
   {
      PrintFormat("SMC: unable to store order block (error=%d).",GetLastError());
      return;
   }
   OrderBlocks[count]=block;
}

void RemoveMitigatedOrderBlocks(const double high,const double low,const double close,
                               const datetime barTime,const bool allowAlert)
{
   double bearishSource=(OrderBlockMitigation==SMC_CLOSE ? close : high);
   double bullishSource=(OrderBlockMitigation==SMC_CLOSE ? close : low);
   for(int i=ArraySize(OrderBlocks)-1;i>=0;i--)
   {
      if(OrderBlocks[i].created==barTime)
         continue;
      bool mitigated=(OrderBlocks[i].bias<0 && bearishSource>OrderBlocks[i].high) ||
                     (OrderBlocks[i].bias>0 && bullishSource<OrderBlocks[i].low);
      if(mitigated)
      {
         string objectName=ObjectPrefix+"OB_"+
                           (OrderBlocks[i].internal ? "Internal_" : "Swing_")+
                           IntegerToString((long)OrderBlocks[i].time)+"_"+
                           IntegerToString(OrderBlocks[i].bias);
         ObjectDelete(0,objectName);
         if(allowAlert)
         {
            string scope=(OrderBlocks[i].internal ? "Internal " : "Swing ");
            bool bullish=(OrderBlocks[i].bias>0);
            bool enabled=(OrderBlocks[i].internal ?
                          (bullish ? AlertInternalBullishOrderBlock : AlertInternalBearishOrderBlock) :
                          (bullish ? AlertSwingBullishOrderBlock : AlertSwingBearishOrderBlock));
            SendPopupAlert(enabled,(bullish ? "Bullish " : "Bearish ")+scope+"order block breakout");
         }
         for(int j=i;j<ArraySize(OrderBlocks)-1;j++) OrderBlocks[j]=OrderBlocks[j+1];
         ArrayResize(OrderBlocks,ArraySize(OrderBlocks)-1);
      }
   }
}

void DrawOrderBlockObjects(const datetime lastTime,const int periodSeconds)
{
   int internalCount=0,swingCount=0;
   int count=ArraySize(OrderBlocks);
   for(int i=count-1;i>=0;i--)
   {
      OrderBlockState block=OrderBlocks[i];
      int limit=block.internal ? InternalOrderBlocksToShow : SwingOrderBlocksToShow;
      string id=(block.internal ? "Internal_" : "Swing_")+
                IntegerToString((long)block.time)+"_"+IntegerToString(block.bias);
      string objectName=ObjectPrefix+"OB_"+id;
      bool visible=true;
      if(block.internal)
      {
         visible=ShowInternalOrderBlocks && internalCount<limit;
         if(visible) internalCount++;
      }
      else
      {
         visible=ShowSwingOrderBlocks && swingCount<limit;
         if(visible) swingCount++;
      }
      if(!visible)
      {
         ObjectDelete(0,objectName);
         continue;
      }
      color base;
      if(Style==SMC_MONOCHROME)
         base=(block.bias<0 ? C'93,96,107' : C'178,181,190');
      else if(block.internal)
         base=(block.bias<0 ? InternalBearishOBColor : InternalBullishOBColor);
      else
         base=(block.bias<0 ? SwingBearishOBColor : SwingBullishOBColor);
      DrawZoneBox(objectName,block.time,
                  lastTime+MathMax(1,periodSeconds)*20,block.high,block.low,
                  WithAlpha(base,51));
   }
}

void UpdatePivot(PivotState &pivot,const double level,const datetime pivotTime,
                 const int pivotIndex)
{
   pivot.previousInitialized=pivot.initialized;
   pivot.previous=pivot.current;
   pivot.current=level;
   pivot.crossed=false;
   pivot.time=pivotTime;
   pivot.index=pivotIndex;
   pivot.initialized=true;
}

void DetectStructure(const bool internal,const int legSize,int &legState,
                     PivotState &pivotHigh,PivotState &pivotLow,int &trendBias,
                     const int i,const int rates_total,
                     const datetime &time[],const double &open[],const double &high[],
                     const double &low[],const double &close[])
{
   int candidate=i+legSize;
   if(candidate>=rates_total) return;
   double priorHigh=-DBL_MAX,priorLow=DBL_MAX;
   for(int j=i;j<candidate;j++)
   {
      if(high[j]>priorHigh) priorHigh=high[j];
      if(low[j]<priorLow) priorLow=low[j];
   }
   bool newHigh=high[candidate]>priorHigh;
   bool newLow=low[candidate]<priorLow;
   int nextLeg=legState;
   if(newHigh) nextLeg=0;
   else if(newLow) nextLeg=1;
   if(nextLeg!=legState)
   {
      bool pivotLowFound=(nextLeg-legState)==1;
      if(pivotLowFound)
      {
         UpdatePivot(pivotLow,low[candidate],time[candidate],candidate);
         if(!internal)
         {
            TrailingBottom=pivotLow;
            TrailingAnchorTime=pivotLow.time;
         }
      }
      else
      {
         UpdatePivot(pivotHigh,high[candidate],time[candidate],candidate);
         if(!internal)
         {
            TrailingTop=pivotHigh;
            TrailingAnchorTime=pivotHigh.time;
         }
      }
      legState=nextLeg;
   }

   bool bullish=(pivotHigh.initialized &&
                 close[i]>pivotHigh.current && close[i+1]<=pivotHigh.current);
   bool bearish=(pivotLow.initialized &&
                 close[i]<pivotLow.current && close[i+1]>=pivotLow.current);
   bool bullishConfluence=true,bearishConfluence=true;
   if(internal && InternalConfluenceFilter)
   {
      double upperWick=high[i]-MathMax(close[i],open[i]);
      double lowerBody=MathMin(close[i],open[i]-low[i]);
      bullishConfluence=upperWick>lowerBody;
      bearishConfluence=upperWick<lowerBody;
   }
   datetime rightTime=time[i]+PeriodSeconds(_Period);
   ENUM_SMC_SIZE size=(internal ? InternalLabelSize : SwingLabelSize);
   if(bullish && !pivotHigh.crossed && bullishConfluence &&
      (!internal || !SwingHigh.initialized || pivotHigh.current!=SwingHigh.current))
   {
      string tag=(trendBias<0 ? "CHoCH" : "BOS");
      color c=BullColor(internal);
      if(i==1)
      {
         bool enabled=(internal ?
                       (tag=="BOS" ? AlertInternalBullishBOS : AlertInternalBullishCHoCH) :
                       (tag=="BOS" ? AlertSwingBullishBOS : AlertSwingBullishCHoCH));
         SendPopupAlert(enabled,(internal ? "Internal " : "Swing ")+
                        "Bullish "+tag);
      }
      if(IsStructureVisible(internal,true,tag))
         DrawHorizontalStructure((internal ? "I_" : "S_")+IntegerToString((int)time[i]),
                                 pivotHigh,rightTime,tag,c,internal,true,size);
      pivotHigh.crossed=true;
      trendBias=1;
      StoreOrderBlock(pivotHigh,internal,1,time,rates_total,i);
   }
   if(bearish && !pivotLow.crossed && bearishConfluence &&
      (!internal || !SwingLow.initialized || pivotLow.current!=SwingLow.current))
   {
      string tag=(trendBias>0 ? "CHoCH" : "BOS");
      color c=BearColor(internal);
      if(i==1)
      {
         bool enabled=(internal ?
                       (tag=="BOS" ? AlertInternalBearishBOS : AlertInternalBearishCHoCH) :
                       (tag=="BOS" ? AlertSwingBearishBOS : AlertSwingBearishCHoCH));
         SendPopupAlert(enabled,(internal ? "Internal " : "Swing ")+
                        "Bearish "+tag);
      }
      if(IsStructureVisible(internal,false,tag))
         DrawHorizontalStructure((internal ? "I_" : "S_")+IntegerToString((int)time[i]),
                                 pivotLow,rightTime,tag,c,internal,false,size);
      pivotLow.crossed=true;
      trendBias=-1;
      StoreOrderBlock(pivotLow,internal,-1,time,rates_total,i);
   }
}

void DetectEqualHighLow(const int size,int &legState,
                        PivotState &equalHigh,PivotState &equalLow,
                        const int i,const int rates_total,const datetime &time[],
                        const double &high[],const double &low[],const double &atr[])
{
   int candidate=i+size;
   if(candidate>=rates_total) return;
   double priorHigh=-DBL_MAX,priorLow=DBL_MAX;
   for(int j=i;j<candidate;j++)
   {
      priorHigh=MathMax(priorHigh,high[j]);
      priorLow=MathMin(priorLow,low[j]);
   }
   int nextLeg=legState;
   if(high[candidate]>priorHigh)
      nextLeg=0;
   else if(low[candidate]<priorLow)
      nextLeg=1;
   if(nextLeg!=legState)
   {
      bool pivotLow=(nextLeg-legState)==1;
      if(pivotLow)
      {
         bool atrOk=(i<ArraySize(atr) && MathIsValidNumber(atr[i]) &&
                     atr[i]<DBL_MAX);
         if(atrOk && equalLow.initialized &&
            MathAbs(equalLow.current-low[candidate])<
            EqualHighLowThreshold*atr[i])
         {
            if(Mode==SMC_PRESENT)
            {
               DeleteObjectsWithPrefix(ObjectPrefix+"EQL_Line_");
               DeleteObjectsWithPrefix(ObjectPrefix+"EQL_Label_");
            }
            string id=IntegerToString((int)time[candidate]);
            color c=BullColor(false);
            string name=ObjectPrefix+"EQL_Line_"+id;
            int labelIndex=(equalLow.index+candidate)/2;
            ObjectCreate(0,name,OBJ_TREND,0,equalLow.time,equalLow.current,
                        time[candidate],low[candidate]);
            ObjectSetInteger(0,name,OBJPROP_COLOR,c);
            ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
            DrawText(ObjectPrefix+"EQL_Label_"+id,time[labelIndex],low[candidate],"EQL",c,
                     ANCHOR_UPPER,(int)EqualHighLowLabelSize);
            if(i==1) SendPopupAlert(AlertEqualLows,"Equal lows detected");
         }
         UpdatePivot(equalLow,low[candidate],time[candidate],candidate);
      }
      else
      {
         bool atrOk=(i<ArraySize(atr) && MathIsValidNumber(atr[i]) &&
                     atr[i]<DBL_MAX);
         if(atrOk && equalHigh.initialized &&
            MathAbs(equalHigh.current-high[candidate])<
            EqualHighLowThreshold*atr[i])
         {
            if(Mode==SMC_PRESENT)
            {
               DeleteObjectsWithPrefix(ObjectPrefix+"EQH_Line_");
               DeleteObjectsWithPrefix(ObjectPrefix+"EQH_Label_");
            }
            string id=IntegerToString((int)time[candidate]);
            color c=BearColor(false);
            string name=ObjectPrefix+"EQH_Line_"+id;
            int labelIndex=(equalHigh.index+candidate)/2;
            ObjectCreate(0,name,OBJ_TREND,0,equalHigh.time,equalHigh.current,
                        time[candidate],high[candidate]);
            ObjectSetInteger(0,name,OBJPROP_COLOR,c);
            ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
            DrawText(ObjectPrefix+"EQH_Label_"+id,time[labelIndex],high[candidate],"EQH",c,
                     ANCHOR_LOWER,(int)EqualHighLowLabelSize);
            if(i==1) SendPopupAlert(AlertEqualHighs,"Equal highs detected");
         }
         UpdatePivot(equalHigh,high[candidate],time[candidate],candidate);
      }
      legState=nextLeg;
   }
}

void DrawSwingLabels(const datetime &time[],const double &high[],const double &low[],
                     const int i,const int swingLength,
                     const PivotState &swingHigh,const PivotState &swingLow)
{
   if(!ShowSwingPoints) return;
   int candidate=i+swingLength;
   bool drawHigh=(swingHigh.initialized && swingHigh.index==candidate);
   bool drawLow=(swingLow.initialized && swingLow.index==candidate);
   if(Mode==SMC_PRESENT && (drawHigh || drawLow))
   {
      DeleteObjectsWithPrefix(ObjectPrefix+"SwingHigh_");
      DeleteObjectsWithPrefix(ObjectPrefix+"SwingLow_");
   }
   if(drawHigh)
      DrawText(ObjectPrefix+"SwingHigh_"+IntegerToString((int)time[candidate]),time[candidate],
               high[candidate],(!swingHigh.previousInitialized ? "H" :
                                swingHigh.current>swingHigh.previous ? "HH" : "LH"),
               BearColor(false),ANCHOR_LOWER);
   if(drawLow)
      DrawText(ObjectPrefix+"SwingLow_"+IntegerToString((int)time[candidate]),time[candidate],
               low[candidate],(!swingLow.previousInitialized ? "L" :
                                swingLow.current<swingLow.previous ? "LL" : "HL"),
               BullColor(false),ANCHOR_UPPER);
}

bool HasFairValueGap(const datetime gapTime,const int bias)
{
   for(int i=0;i<ArraySize(FairValueGaps);i++)
      if(FairValueGaps[i].time==gapTime && FairValueGaps[i].bias==bias)
         return true;
   return false;
}

bool RegisterFairValueGap(const string id,const datetime gapTime,const int bias,
                          const double mitigationLevel,const double otherLevel,
                          const datetime left,const datetime right,const color zoneColor,
                          const double firstTop,const double firstBottom,
                          const double secondTop,const double secondBottom)
{
   if(HasFairValueGap(gapTime,bias))
      return false;
   int count=ArraySize(FairValueGaps);
   if(ArrayResize(FairValueGaps,count+1)!=count+1)
   {
      PrintFormat("SMC: unable to store FVG state (error=%d).",GetLastError());
      return false;
   }
   FairValueGaps[count].top=(bias>0 ? otherLevel : mitigationLevel);
   FairValueGaps[count].bottom=(bias>0 ? mitigationLevel : otherLevel);
   FairValueGaps[count].time=gapTime;
   FairValueGaps[count].bias=bias;
   DrawZoneBox(ObjectPrefix+"FVG_"+id+"_1",left,right,firstTop,firstBottom,zoneColor);
   DrawZoneBox(ObjectPrefix+"FVG_"+id+"_2",left,right,secondTop,secondBottom,zoneColor);
   return true;
}

bool IsFVGBarOpeningInChartBar(const datetime fvgBarTime,const datetime chartBarTime)
{
   int chartPeriodSeconds=PeriodSeconds(_Period);
   if(chartPeriodSeconds<=0)
      chartPeriodSeconds=60;
   return fvgBarTime>=chartBarTime &&
          fvgBarTime<chartBarTime+chartPeriodSeconds;
}

void UpdateFairValueGapsOnTick(const datetime chartBarTime)
{
   if(!ShowFairValueGaps)
      return;
   ENUM_TIMEFRAMES timeframe=(FairValueGapTimeframe==PERIOD_CURRENT ?
                              _Period : FairValueGapTimeframe);
   MqlRates bars[];
   ArraySetAsSeries(bars,true);
   int copied=CopyRates(_Symbol,timeframe,0,4,bars);
   if(copied<4)
   {
      PrintFormat("SMC: unable to update FVG timeframe %s history (bars=%d, error=%d).",
                  EnumToString(timeframe),copied,GetLastError());
      return;
   }

   for(int i=ArraySize(FairValueGaps)-1;i>=0;i--)
   {
      bool mitigated=(FairValueGaps[i].bias>0 &&
                      bars[0].low<FairValueGaps[i].bottom) ||
                     (FairValueGaps[i].bias<0 &&
                      bars[0].high>FairValueGaps[i].top);
      if(!mitigated)
         continue;
      string id=(FairValueGaps[i].bias>0 ? "Bull_" : "Bear_")+
                IntegerToString((int)FairValueGaps[i].time);
      ObjectDelete(0,ObjectPrefix+"FVG_"+id+"_1");
      ObjectDelete(0,ObjectPrefix+"FVG_"+id+"_2");
      for(int j=i;j<ArraySize(FairValueGaps)-1;j++)
         FairValueGaps[j]=FairValueGaps[j+1];
      ArrayResize(FairValueGaps,ArraySize(FairValueGaps)-1);
   }

   if(!IsFVGBarOpeningInChartBar(bars[0].time,chartBarTime))
      return;
   double signedChange=(bars[2].close-bars[2].open)/
                       MathMax(MathAbs(bars[2].open)*100.0,_Point);
   bool bullish=(bars[1].low>bars[3].high &&
                 bars[2].close>bars[3].high &&
                 (!FairValueGapAutoThreshold ||
                  signedChange>CurrentFVGThreshold));
   bool bearish=(bars[1].high<bars[3].low &&
                 bars[2].close<bars[3].low &&
                 (!FairValueGapAutoThreshold ||
                  -signedChange>CurrentFVGThreshold));
   int periodSeconds=PeriodSeconds(_Period);
   if(periodSeconds<=0) periodSeconds=60;
   datetime right=bars[1].time+FairValueGapExtend*periodSeconds;
   if(bullish && !HasFairValueGap(bars[2].time,1))
   {
      string id="Bull_"+IntegerToString((int)bars[2].time);
      double middle=(bars[1].low+bars[3].high)*0.5;
      if(RegisterFairValueGap(id,bars[2].time,1,bars[3].high,bars[1].low,
                              bars[2].time,right,WithAlpha(BullishFVGColor,77),
                              bars[1].low,middle,middle,bars[3].high))
         SendPopupAlert(AlertBullishFVG,"Bullish fair value gap");
   }
   if(bearish && !HasFairValueGap(bars[2].time,-1))
   {
      string id="Bear_"+IntegerToString((int)bars[2].time);
      double middle=(bars[1].high+bars[3].low)*0.5;
      if(RegisterFairValueGap(id,bars[2].time,-1,bars[3].low,bars[1].high,
                              bars[2].time,right,WithAlpha(BearishFVGColor,77),
                              bars[1].high,middle,middle,bars[3].low))
         SendPopupAlert(AlertBearishFVG,"Bearish fair value gap");
   }
}

bool RefreshCurrentFVGThreshold()
{
   if(!ShowFairValueGaps)
      return true;
   ENUM_TIMEFRAMES timeframe=(FairValueGapTimeframe==PERIOD_CURRENT ?
                              _Period : FairValueGapTimeframe);
   MqlRates bars[];
   ArraySetAsSeries(bars,true);
   int copied=CopyRates(_Symbol,timeframe,0,MaxBarsToProcess,bars);
   if(copied<3)
   {
      PrintFormat("SMC: unable to refresh FVG threshold for %s (bars=%d, error=%d).",
                  EnumToString(timeframe),copied,GetLastError());
      return false;
   }

   double cumulativeDelta=0.0;
   int sampleCount=0;
   for(int i=copied-2;i>=1;i--)
   {
      double change=(bars[i].close-bars[i].open)/
                    MathMax(MathAbs(bars[i].open)*100.0,_Point);
      cumulativeDelta+=MathAbs(change);
      sampleCount++;
   }
   CurrentFVGThreshold=(sampleCount>0 ? cumulativeDelta/sampleCount*2.0 : 0.0);
   return true;
}

void DrawFVGs()
{
   if(!ShowFairValueGaps) return;
   ENUM_TIMEFRAMES timeframe=(FairValueGapTimeframe==PERIOD_CURRENT ?
                              _Period : FairValueGapTimeframe);
   MqlRates bars[];
   ArraySetAsSeries(bars,true);
   int copied=CopyRates(_Symbol,timeframe,0,MaxBarsToProcess,bars);
   if(copied<3)
   {
      PrintFormat("SMC: unable to load FVG timeframe %s history (bars=%d, error=%d).",
                  EnumToString(timeframe),copied,GetLastError());
      return;
   }
   double thresholds[];
   ArrayResize(thresholds,copied);
   ArraySetAsSeries(thresholds,true);
   double cumulativeDelta=0.0;
   int sampleCount=0;
   for(int i=copied-3;i>=0;i--)
   {
      double change=(bars[i+1].close-bars[i+1].open)/
                    MathMax(MathAbs(bars[i+1].open)*100.0,_Point);
      cumulativeDelta+=MathAbs(change);
      sampleCount++;
      thresholds[i]=cumulativeDelta/sampleCount*2.0;
   }
   CurrentFVGThreshold=thresholds[0];
   int periodSeconds=PeriodSeconds(_Period);
   if(periodSeconds<=0) periodSeconds=60;
   int drawn=0;
   for(int i=0;i<copied-2 && drawn<100;i++)
   {
      double signedChange=(bars[i+1].close-bars[i+1].open)/
                          MathMax(MathAbs(bars[i+1].open)*100.0,_Point);
      datetime right=bars[i].time+FairValueGapExtend*periodSeconds;
      bool bullish=(bars[i].low>bars[i+2].high &&
                   bars[i+1].close>bars[i+2].high &&
                   (!FairValueGapAutoThreshold || signedChange>thresholds[i]));
      bool bearish=(bars[i].high<bars[i+2].low &&
                   bars[i+1].close<bars[i+2].low &&
                   (!FairValueGapAutoThreshold || -signedChange>thresholds[i]));
      if(i==0)
      {
         bullish=false;
         bearish=false;
      }
      for(int newer=i-1;newer>=0 && (bullish || bearish);--newer)
      {
         if(bullish && bars[newer].low<bars[i+2].high) bullish=false;
         if(bearish && bars[newer].high>bars[i+2].low) bearish=false;
      }
      if(bullish)
      {
         string id="Bull_"+IntegerToString((int)bars[i+1].time);
         double middle=(bars[i].low+bars[i+2].high)*0.5;
         RegisterFairValueGap(id,bars[i+1].time,1,bars[i+2].high,bars[i].low,
                              bars[i+1].time,right,WithAlpha(BullishFVGColor,77),
                              bars[i].low,middle,middle,bars[i+2].high);
         drawn++;
      }
      if(bearish && drawn<100)
      {
         string id="Bear_"+IntegerToString((int)bars[i+1].time);
         double middle=(bars[i].high+bars[i+2].low)*0.5;
         RegisterFairValueGap(id,bars[i+1].time,-1,bars[i+2].low,bars[i].high,
                              bars[i+1].time,right,WithAlpha(BearishFVGColor,77),
                              bars[i].high,middle,middle,bars[i+2].low);
         drawn++;
      }
   }
}

void DrawPreviousPeriodLevels(const ENUM_TIMEFRAMES timeframe,const string label,
                              const ENUM_SMC_LINE_STYLE style,const color lineColor,
                              const datetime lastTime,const int ratesTotal,
                              const datetime &time[],const double &high[],
                              const double &low[])
{
   if(PeriodSeconds(_Period)>PeriodSeconds(timeframe)) return;
   int shift=(PeriodSeconds(_Period)==PeriodSeconds(timeframe) ? 0 : 1);
   double previousHigh=iHigh(_Symbol,timeframe,shift);
   double previousLow=iLow(_Symbol,timeframe,shift);
   datetime start=iTime(_Symbol,timeframe,shift);
   if(start==0 || previousHigh==0 || previousLow==0) return;
   datetime periodEnd=(shift==0 ? lastTime+MathMax(1,PeriodSeconds(_Period)) :
                       iTime(_Symbol,timeframe,0));
   datetime highTime=start,lowTime=start;
   bool highAnchorFound=false,lowAnchorFound=false;
   int oldestShift=iBarShift(_Symbol,_Period,start,false);
   int newestShift=iBarShift(_Symbol,_Period,periodEnd-1,false);
   if(oldestShift>=0 && newestShift>=0 && oldestShift>=newestShift)
   {
      for(int i=oldestShift;i>=newestShift;i--)
      {
         if(time[i]<start || time[i]>=periodEnd) continue;
         if(!highAnchorFound && high[i]==previousHigh)
         {
            highTime=time[i];
            highAnchorFound=true;
         }
         if(!lowAnchorFound && low[i]==previousLow)
         {
            lowTime=time[i];
            lowAnchorFound=true;
         }
         if(highAnchorFound && lowAnchorFound)
            break;
      }
   }
   datetime finish=lastTime+PeriodSeconds(_Period)*20;
   string highName=ObjectPrefix+label+"H";
   string lowName=ObjectPrefix+label+"L";
   if(ObjectFind(0,highName)<0)
      ObjectCreate(0,highName,OBJ_TREND,0,highTime,previousHigh,finish,previousHigh);
   else
   {
      ObjectMove(0,highName,0,highTime,previousHigh);
      ObjectMove(0,highName,1,finish,previousHigh);
   }
   if(ObjectFind(0,lowName)<0)
      ObjectCreate(0,lowName,OBJ_TREND,0,lowTime,previousLow,finish,previousLow);
   else
   {
      ObjectMove(0,lowName,0,lowTime,previousLow);
      ObjectMove(0,lowName,1,finish,previousLow);
   }
   ObjectSetInteger(0,highName,OBJPROP_COLOR,lineColor);
   ObjectSetInteger(0,lowName,OBJPROP_COLOR,lineColor);
   ObjectSetInteger(0,highName,OBJPROP_STYLE,LineStyle(style));
   ObjectSetInteger(0,lowName,OBJPROP_STYLE,LineStyle(style));
   ObjectSetInteger(0,highName,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,lowName,OBJPROP_RAY_RIGHT,false);
   DrawText(ObjectPrefix+label+"H_Label",finish,previousHigh,"P"+label+"H",lineColor,
            ANCHOR_LEFT);
   DrawText(ObjectPrefix+label+"L_Label",finish,previousLow,"P"+label+"L",lineColor,
            ANCHOR_LEFT);
}

void DrawTrailingLevels(const datetime lastTime,const int periodSeconds)
{
   if(!ShowStrongWeakHighLow || !TrailingTop.initialized ||
      !TrailingBottom.initialized) return;
   datetime end=lastTime+periodSeconds*20;
   string hi=ObjectPrefix+"StrongWeak_High",lo=ObjectPrefix+"StrongWeak_Low";
   if(ObjectFind(0,hi)<0)
      ObjectCreate(0,hi,OBJ_TREND,0,TrailingTop.time,TrailingTop.current,
                   end,TrailingTop.current);
   else
   {
      ObjectMove(0,hi,0,TrailingTop.time,TrailingTop.current);
      ObjectMove(0,hi,1,end,TrailingTop.current);
   }
   if(ObjectFind(0,lo)<0)
      ObjectCreate(0,lo,OBJ_TREND,0,TrailingBottom.time,TrailingBottom.current,
                   end,TrailingBottom.current);
   else
   {
      ObjectMove(0,lo,0,TrailingBottom.time,TrailingBottom.current);
      ObjectMove(0,lo,1,end,TrailingBottom.current);
   }
   ObjectSetInteger(0,hi,OBJPROP_COLOR,BearColor(false));
   ObjectSetInteger(0,lo,OBJPROP_COLOR,BullColor(false));
   ObjectSetInteger(0,hi,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,lo,OBJPROP_RAY_RIGHT,false);
   DrawText(ObjectPrefix+"StrongWeak_High_Label",end,TrailingTop.current,
            SwingBias<0 ? "Strong High" : "Weak High",BearColor(false),ANCHOR_LEFT);
   DrawText(ObjectPrefix+"StrongWeak_Low_Label",end,TrailingBottom.current,
            SwingBias>0 ? "Strong Low" : "Weak Low",BullColor(false),ANCHOR_LEFT);
}

void UpdateTrailingLevelsOnTick(const datetime currentTime,const double currentHigh,
                                const double currentLow,const int periodSeconds)
{
   if(!ShowStrongWeakHighLow && !ShowPremiumDiscountZones)
      return;

   if(TrailingTop.initialized && currentHigh>=TrailingTop.current)
   {
      TrailingTop.current=currentHigh;
      TrailingTop.time=currentTime;
      TrailingTop.index=0;
   }
   if(TrailingBottom.initialized && currentLow<=TrailingBottom.current)
   {
      TrailingBottom.current=currentLow;
      TrailingBottom.time=currentTime;
      TrailingBottom.index=0;
   }

   if(!ShowStrongWeakHighLow || !TrailingTop.initialized ||
      !TrailingBottom.initialized)
   {
      if(ShowPremiumDiscountZones && TrailingTop.initialized &&
         TrailingBottom.initialized)
         DrawPremiumDiscount(currentTime,MathMax(1,periodSeconds),0);
      return;
   }

   int seconds=MathMax(1,periodSeconds);
   datetime end=currentTime+seconds*20;
   string highLine=ObjectPrefix+"StrongWeak_High";
   string lowLine=ObjectPrefix+"StrongWeak_Low";
   string highLabel=ObjectPrefix+"StrongWeak_High_Label";
   string lowLabel=ObjectPrefix+"StrongWeak_Low_Label";
   if(ObjectFind(0,highLine)>=0)
   {
      ObjectMove(0,highLine,0,TrailingTop.time,TrailingTop.current);
      ObjectMove(0,highLine,1,end,TrailingTop.current);
   }
   if(ObjectFind(0,lowLine)>=0)
   {
      ObjectMove(0,lowLine,0,TrailingBottom.time,TrailingBottom.current);
      ObjectMove(0,lowLine,1,end,TrailingBottom.current);
   }
   if(ObjectFind(0,highLabel)>=0)
   {
      ObjectMove(0,highLabel,0,end,TrailingTop.current);
      ObjectSetString(0,highLabel,OBJPROP_TEXT,
                      SwingBias<0 ? "Strong High" : "Weak High");
   }
   if(ObjectFind(0,lowLabel)>=0)
   {
      ObjectMove(0,lowLabel,0,end,TrailingBottom.current);
      ObjectSetString(0,lowLabel,OBJPROP_TEXT,
                      SwingBias>0 ? "Strong Low" : "Weak Low");
   }
   if(ShowPremiumDiscountZones)
      DrawPremiumDiscount(currentTime,seconds,0);
}

void DrawPremiumDiscount(const datetime lastTime,const int periodSeconds,
                         const int lastIndex)
{
   if(!ShowPremiumDiscountZones || !TrailingTop.initialized ||
      !TrailingBottom.initialized || TrailingTop.current<=TrailingBottom.current)
      return;
   double top=TrailingTop.current,bottom=TrailingBottom.current;
   datetime start=TrailingAnchorTime;
   if(start==0)
      start=(TrailingTop.time>TrailingBottom.time ? TrailingTop.time : TrailingBottom.time);
   datetime finish=lastTime+periodSeconds*20;
   double premiumBottom=0.95*top+0.05*bottom;
   double eqTop=0.525*top+0.475*bottom;
   double eqBottom=0.525*bottom+0.475*top;
   double discountTop=0.95*bottom+0.05*top;
   DrawZoneBox(ObjectPrefix+"Zone_Premium",start,finish,top,premiumBottom,
               WithAlpha(PremiumZoneColor,45));
   DrawZoneBox(ObjectPrefix+"Zone_Equilibrium",start,finish,eqTop,eqBottom,
               WithAlpha(EquilibriumZoneColor,45));
   DrawZoneBox(ObjectPrefix+"Zone_Discount",start,finish,discountTop,bottom,
               WithAlpha(DiscountZoneColor,45));
   datetime premiumLabelTime=start+(finish-start)/2;
   DrawText(ObjectPrefix+"Zone_Premium_Label",premiumLabelTime,top,"Premium",PremiumZoneColor,ANCHOR_LEFT);
   DrawText(ObjectPrefix+"Zone_Equilibrium_Label",finish,(eqTop+eqBottom)/2,
            "Equilibrium",EquilibriumZoneColor,ANCHOR_LEFT);
   DrawText(ObjectPrefix+"Zone_Discount_Label",premiumLabelTime,bottom,"Discount",DiscountZoneColor,ANCHOR_LEFT);
}

void ResetState()
{
   ZeroMemory(SwingHigh); ZeroMemory(SwingLow);
   ZeroMemory(InternalHigh); ZeroMemory(InternalLow);
   ZeroMemory(EqualHigh); ZeroMemory(EqualLow);
   ZeroMemory(TrailingTop); ZeroMemory(TrailingBottom);
   TrailingAnchorTime=0;
   SwingBias=0; InternalBias=0;
   SwingLeg=0; InternalLeg=0;    EqualLeg=0;
   for(int i=0;i<ArraySize(LatestStructures);i++)
   {
      LatestStructures[i].valid=false;
      LatestStructures[i].id="";
      LatestStructures[i].tag="";
   }
   PresentStructuresDirty=false;
   ArrayResize(OrderBlocks,0);
   ArrayResize(FairValueGaps,0);
   CurrentFVGThreshold=0.0;
   CumulativeRangeClosedSum=0.0;
}

int OnInit()
{
   if(SwingLength<10 || MaxBarsToProcess<MathMax(SwingLength,EqualHighLowConfirmationBars)+3 ||
      MaxBarsToProcess>10000 || EqualHighLowConfirmationBars<1 ||
      InternalOrderBlocksToShow<1 || InternalOrderBlocksToShow>20 ||
      SwingOrderBlocksToShow<1 || SwingOrderBlocksToShow>20 ||
      FairValueGapExtend<0 || EqualHighLowThreshold<0.0 ||
      EqualHighLowThreshold>0.5 || SetupHistoryBars<200 ||
      SetupHistoryBars>10000 || SetupMaxEventAgeBars<1 ||
      SetupMaxEventAgeBars>1000)
      return INIT_PARAMETERS_INCORRECT;
   ObjectPrefix="SC"+IntegerToString((int)(ChartID()%100000))+"_"+
                IntegerToString((int)(GetTickCount()%100000))+"_";
   SetIndexBuffer(0,CandleOpen,INDICATOR_DATA);
   SetIndexBuffer(1,CandleHigh,INDICATOR_DATA);
   SetIndexBuffer(2,CandleLow,INDICATOR_DATA);
   SetIndexBuffer(3,CandleClose,INDICATOR_DATA);
   SetIndexBuffer(4,CandleColorIndex,INDICATOR_COLOR_INDEX);
   ArraySetAsSeries(CandleOpen,true);
   ArraySetAsSeries(CandleHigh,true);
   ArraySetAsSeries(CandleLow,true);
   ArraySetAsSeries(CandleClose,true);
   ArraySetAsSeries(CandleColorIndex,true);
   PlotIndexSetInteger(0,PLOT_COLOR_INDEXES,2);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,0,BullColor(false));
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,1,BearColor(false));
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   IndicatorSetString(INDICATOR_SHORTNAME,"Smart Money Concepts [LuxAlgo]");
   SetupOverlayLastM5Bar=0;
   SetupOverlayHistoryWarningLogged=false;
   if(ShowSetupOverlay && !EventSetTimer(5))
      PrintFormat("SMC setup overlay timer could not be started. Error=%d; "
                  "history retry will occur on chart ticks.",GetLastError());
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteSMCObjects();
}

void OnTimer()
{
   RefreshSetupOverlay();
}

void ShiftPivotIndex(PivotState &pivot)
{
   if(pivot.initialized)
      pivot.index++;
}

void UpdateCurrentCalculationValues(const double currentHigh,const double currentLow,
                                    const double previousClose,const int ratesTotal)
{
   int count=ArraySize(ParsedHighs);
   if(count<2 || ratesTotal<2)
      return;
   double trueRange=MathMax(currentHigh-currentLow,
                     MathMax(MathAbs(currentHigh-previousClose),
                             MathAbs(currentLow-previousClose)));
   TrueRangeCache[0]=trueRange;
   MeanRangeCache[0]=(CumulativeRangeClosedSum+trueRange)/(ratesTotal-1);

   if(AtrCache[1]==DBL_MAX)
   {
      double seedSum=0.0;
      for(int i=1;i<count;i++)
         seedSum+=TrueRangeCache[i];
      AtrCache[0]=(seedSum+trueRange)/count;
   }
   else
      AtrCache[0]=(AtrCache[1]*199.0+trueRange)/200.0;

   double volatilityMeasure=(OrderBlockFilter==SMC_ATR ?
                             AtrCache[0] : MeanRangeCache[0]);
   bool volatileBar=(currentHigh-currentLow)>=2.0*volatilityMeasure;
   ParsedHighs[0]=(volatileBar ? currentLow : currentHigh);
   ParsedLows[0]=(volatileBar ? currentHigh : currentLow);
}

bool AdvanceCalculationCaches(const int ratesTotal,const double &high[],
                             const double &low[],const double &close[])
{
   int oldCount=ArraySize(ParsedHighs);
   int newCount=MathMin(ratesTotal,MaxBarsToProcess);
   if(oldCount<2 || ArraySize(ParsedLows)!=oldCount ||
      ArraySize(AtrCache)!=oldCount || ArraySize(MeanRangeCache)!=oldCount ||
      ArraySize(TrueRangeCache)!=oldCount ||
      oldCount!=MathMin(LastRatesTotal,MaxBarsToProcess) ||
      ratesTotal<LastRatesTotal || ratesTotal>LastRatesTotal+1)
      return false;

   if(ArrayResize(ParsedHighs,newCount)!=newCount ||
      ArrayResize(ParsedLows,newCount)!=newCount ||
      ArrayResize(AtrCache,newCount)!=newCount ||
      ArrayResize(MeanRangeCache,newCount)!=newCount ||
      ArrayResize(TrueRangeCache,newCount)!=newCount)
   {
      PrintFormat("SMC: unable to advance calculation caches (error=%d).",GetLastError());
      return false;
   }

   double closedBarTrueRange=MathMax(high[1]-low[1],
                              MathMax(MathAbs(high[1]-close[2]),
                                      MathAbs(low[1]-close[2])));
   CumulativeRangeClosedSum+=closedBarTrueRange;
   for(int i=newCount-1;i>=1;i--)
   {
      int source=i-1;
      if(source<oldCount)
      {
         ParsedHighs[i]=ParsedHighs[source];
         ParsedLows[i]=ParsedLows[source];
         AtrCache[i]=AtrCache[source];
         MeanRangeCache[i]=MeanRangeCache[source];
         TrueRangeCache[i]=TrueRangeCache[source];
      }
   }
   ArraySetAsSeries(ParsedHighs,true);
   ArraySetAsSeries(ParsedLows,true);
   ArraySetAsSeries(AtrCache,true);
   ArraySetAsSeries(MeanRangeCache,true);
   ArraySetAsSeries(TrueRangeCache,true);

   TrueRangeCache[1]=closedBarTrueRange;
   MeanRangeCache[1]=(ratesTotal>2 ?
                      CumulativeRangeClosedSum/(ratesTotal-2) : DBL_MAX);
   if(AtrCache[2]==DBL_MAX)
   {
      double seedSum=closedBarTrueRange;
      for(int i=2;i<newCount;i++)
         seedSum+=TrueRangeCache[i];
      AtrCache[1]=seedSum/newCount;
   }
   else
      AtrCache[1]=(AtrCache[2]*199.0+closedBarTrueRange)/200.0;
   double closedVolatility=(OrderBlockFilter==SMC_ATR ?
                            AtrCache[1] : MeanRangeCache[1]);
   bool closedVolatile=(high[1]-low[1])>=2.0*closedVolatility;
   ParsedHighs[1]=(closedVolatile ? low[1] : high[1]);
   ParsedLows[1]=(closedVolatile ? high[1] : low[1]);

   double previousClose=(ratesTotal>1 ? close[1] : close[0]);
   UpdateCurrentCalculationValues(high[0],low[0],previousClose,ratesTotal);

   ShiftPivotIndex(SwingHigh);
   ShiftPivotIndex(SwingLow);
   ShiftPivotIndex(InternalHigh);
   ShiftPivotIndex(InternalLow);
   ShiftPivotIndex(EqualHigh);
   ShiftPivotIndex(EqualLow);
   ShiftPivotIndex(TrailingTop);
   ShiftPivotIndex(TrailingBottom);
   for(int i=0;i<ArraySize(LatestStructures);i++)
      ShiftPivotIndex(LatestStructures[i].pivot);
   return true;
}

void RenderPreviousLevels(const int ratesTotal,const datetime &time[],
                          const double &high[],const double &low[])
{
   if(ShowDailyLevels)
      DrawPreviousPeriodLevels(PERIOD_D1,"D",DailyLevelsStyle,DailyLevelsColor,
                               time[0],ratesTotal,time,high,low);
   if(ShowWeeklyLevels)
      DrawPreviousPeriodLevels(PERIOD_W1,"W",WeeklyLevelsStyle,WeeklyLevelsColor,
                               time[0],ratesTotal,time,high,low);
   if(ShowMonthlyLevels)
      DrawPreviousPeriodLevels(PERIOD_MN1,"M",MonthlyLevelsStyle,MonthlyLevelsColor,
                               time[0],ratesTotal,time,high,low);
}

bool ProcessNewBar(const int ratesTotal,const datetime &time[],const double &open[],
                   const double &high[],const double &low[],const double &close[])
{
   if(!AdvanceCalculationCaches(ratesTotal,high,low,close))
      return false;

   DetectStructure(false,SwingLength,SwingLeg,SwingHigh,SwingLow,SwingBias,
                   1,ratesTotal,time,open,high,low,close);
   DetectStructure(true,5,InternalLeg,InternalHigh,InternalLow,InternalBias,
                   1,ratesTotal,time,open,high,low,close);
   if(ShowEqualHighsLows)
      DetectEqualHighLow(EqualHighLowConfirmationBars,EqualLeg,EqualHigh,EqualLow,
                         1,ratesTotal,time,high,low,AtrCache);
   if(ShowSwingPoints)
      DrawSwingLabels(time,high,low,1,SwingLength,SwingHigh,SwingLow);

   if(ShowStrongWeakHighLow || ShowPremiumDiscountZones)
   {
      if(TrailingTop.initialized && high[0]>=TrailingTop.current)
      {
         TrailingTop.current=high[0];
         TrailingTop.time=time[0];
         TrailingTop.index=0;
      }
      if(TrailingBottom.initialized && low[0]<=TrailingBottom.current)
      {
         TrailingBottom.current=low[0];
         TrailingBottom.time=time[0];
         TrailingBottom.index=0;
      }
   }
   RemoveMitigatedOrderBlocks(high[1],low[1],close[1],time[1],true);
   if(ColorCandles)
   {
      CandleOpen[1]=open[1];
      CandleHigh[1]=high[1];
      CandleLow[1]=low[1];
      CandleClose[1]=close[1];
      CandleColorIndex[1]=(InternalBias>0 ? 0 : 1);
      CandleOpen[0]=open[0];
      CandleHigh[0]=high[0];
      CandleLow[0]=low[0];
      CandleClose[0]=close[0];
      CandleColorIndex[0]=(InternalBias>0 ? 0 : 1);
   }
   else
   {
      CandleOpen[1]=EMPTY_VALUE;
      CandleHigh[1]=EMPTY_VALUE;
      CandleLow[1]=EMPTY_VALUE;
      CandleClose[1]=EMPTY_VALUE;
      CandleOpen[0]=EMPTY_VALUE;
      CandleHigh[0]=EMPTY_VALUE;
      CandleLow[0]=EMPTY_VALUE;
      CandleClose[0]=EMPTY_VALUE;
   }

   RefreshCurrentFVGThreshold();
   UpdateFairValueGapsOnTick(time[0]);
   int periodSeconds=PeriodSeconds(_Period);
   if(periodSeconds<=0) periodSeconds=60;
   DrawOrderBlockObjects(time[0],periodSeconds);
   datetime structureRight=time[0]+periodSeconds;
   for(int i=0;i<ArraySize(LatestStructures);i++)
      if(LatestStructures[i].valid)
         LatestStructures[i].rightTime=structureRight;
   ExtendPresentStructures(structureRight);
   RenderPresentStructures();
   RenderPreviousLevels(ratesTotal,time,high,low);
   DrawTrailingLevels(time[0],periodSeconds);
   DrawPremiumDiscount(time[0],periodSeconds,ratesTotal-1);
   RefreshSetupOverlay();
   ChartRedraw(0);
   LastProcessedBar=time[0];
   LastRatesTotal=ratesTotal;
   return true;
}

int OnCalculate(const int rates_total,const int prev_calculated,
                const datetime &time[],const double &open[],const double &high[],
                const double &low[],const double &close[],const long &tick_volume[],
                const long &volume[],const int &spread[])
{
   if(rates_total<MathMax(SwingLength,EqualHighLowConfirmationBars)+3)
      return 0;
   ArraySetAsSeries(time,true);
   ArraySetAsSeries(open,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);
   if(prev_calculated>0 && LastProcessedBar>0 &&
      time[0]>LastProcessedBar)
   {
      if(ProcessNewBar(rates_total,time,open,high,low,close))
         return rates_total;
   }
   if(prev_calculated>0 && LastProcessedBar==time[0])
   {
      UpdateCurrentCalculationValues(high[0],low[0],close[1],rates_total);
      UpdateTrailingLevelsOnTick(time[0],high[0],low[0],PeriodSeconds(_Period));
      if(ColorCandles)
      {
         CandleOpen[0]=open[0];
         CandleHigh[0]=high[0];
         CandleLow[0]=low[0];
         CandleClose[0]=close[0];
         CandleColorIndex[0]=(InternalBias>0 ? 0 : 1);
      }
      else
      {
         CandleOpen[0]=EMPTY_VALUE;
         CandleHigh[0]=EMPTY_VALUE;
         CandleLow[0]=EMPTY_VALUE;
         CandleClose[0]=EMPTY_VALUE;
      }
      UpdateFairValueGapsOnTick(time[0]);
      DrawOrderBlockObjects(time[0],MathMax(1,PeriodSeconds(_Period)));
      datetime structureRight=time[0]+MathMax(1,PeriodSeconds(_Period));
      for(int i=0;i<ArraySize(LatestStructures);i++)
         if(LatestStructures[i].valid)
            LatestStructures[i].rightTime=structureRight;
      ExtendPresentStructures(structureRight);
      RenderPresentStructures();
      RefreshSetupOverlay();
      ChartRedraw(0);
      return rates_total;
   }
   LastProcessedBar=time[0];
   LastRatesTotal=rates_total;
   AlertsArmed=false;
   DeleteSMCObjects();
   ResetState();

   int count=MathMin(rates_total,MaxBarsToProcess);
   for(int i=rates_total-1;i>=count;i--)
   {
      CandleOpen[i]=EMPTY_VALUE;
      CandleHigh[i]=EMPTY_VALUE;
      CandleLow[i]=EMPTY_VALUE;
      CandleClose[i]=EMPTY_VALUE;
      CandleColorIndex[i]=0;
   }
   int oldest=count-1;
   ArrayResize(AtrCache,count);
   ArrayResize(MeanRangeCache,count);
   ArrayResize(TrueRangeCache,count);
   ArrayResize(ParsedHighs,count);
   ArrayResize(ParsedLows,count);
   ArraySetAsSeries(AtrCache,true);
   ArraySetAsSeries(MeanRangeCache,true);
   ArraySetAsSeries(TrueRangeCache,true);
   ArraySetAsSeries(ParsedHighs,true);
   ArraySetAsSeries(ParsedLows,true);
   double cumulativeRange=0.0;
   for(int i=rates_total-1;i>=count;i--)
   {
      double previousClose=(i+1<rates_total ? close[i+1] : close[i]);
      cumulativeRange+=MathMax(high[i]-low[i],
                        MathMax(MathAbs(high[i]-previousClose),
                                MathAbs(low[i]-previousClose)));
   }
   for(int i=oldest;i>=0;i--)
   {
      double previousClose=(i+1<rates_total ? close[i+1] : close[i]);
      double trueRange=MathMax(high[i]-low[i],
                        MathMax(MathAbs(high[i]-previousClose),MathAbs(low[i]-previousClose)));
      TrueRangeCache[i]=trueRange;
      cumulativeRange+=trueRange;
      int barIndex=rates_total-1-i;
      MeanRangeCache[i]=(barIndex>0 ? cumulativeRange/barIndex : DBL_MAX);
      CandleOpen[i]=EMPTY_VALUE; CandleHigh[i]=EMPTY_VALUE;
      CandleLow[i]=EMPTY_VALUE; CandleClose[i]=EMPTY_VALUE;
      CandleColorIndex[i]=0;
      AtrCache[i]=DBL_MAX;
   }
   int seedIndex=MathMin(oldest,MathMax(0,count-200));
   int seedCount=MathMin(200,count-seedIndex);
   double seedSum=0.0;
   for(int i=seedIndex;i<seedIndex+seedCount;i++)
   {
      double previousClose=(i+1<rates_total ? close[i+1] : close[i]);
      seedSum+=MathMax(high[i]-low[i],
                       MathMax(MathAbs(high[i]-previousClose),MathAbs(low[i]-previousClose)));
   }
   AtrCache[seedIndex]=(seedCount>0 ? seedSum/seedCount : TrueRangeCache[seedIndex]);
   for(int i=seedIndex-1;i>=0;i--)
      AtrCache[i]=(AtrCache[i+1]*199.0+TrueRangeCache[i])/200.0;
   for(int i=oldest;i>=0;i--)
   {
      double volatilityMeasure=(OrderBlockFilter==SMC_ATR ?
                                AtrCache[i] : MeanRangeCache[i]);
      bool volatileBar=(high[i]-low[i])>=2.0*volatilityMeasure;
      ParsedHighs[i]=(volatileBar ? low[i] : high[i]);
      ParsedLows[i]=(volatileBar ? high[i] : low[i]);
   }
   CumulativeRangeClosedSum=cumulativeRange-TrueRangeCache[0];

   for(int i=oldest-MathMax(SwingLength,EqualHighLowConfirmationBars)-1;i>=0;i--)
   {
      if(i+1>=rates_total) continue;
      if(ShowStrongWeakHighLow || ShowPremiumDiscountZones)
      {
         if(TrailingTop.initialized && high[i]>=TrailingTop.current)
         {
            TrailingTop.current=high[i]; TrailingTop.time=time[i]; TrailingTop.index=i;
         }
         if(TrailingBottom.initialized && low[i]<=TrailingBottom.current)
         {
            TrailingBottom.current=low[i]; TrailingBottom.time=time[i]; TrailingBottom.index=i;
         }
      }
      if(i>0)
      {
         DetectStructure(false,SwingLength,SwingLeg,SwingHigh,SwingLow,SwingBias,
                         i,rates_total,time,open,high,low,close);
         DetectStructure(true,5,InternalLeg,InternalHigh,InternalLow,InternalBias,
                         i,rates_total,time,open,high,low,close);
         if(ShowEqualHighsLows)
            DetectEqualHighLow(EqualHighLowConfirmationBars,EqualLeg,
                               EqualHigh,EqualLow,i,rates_total,time,high,low,AtrCache);
         if(ShowSwingPoints)
            DrawSwingLabels(time,high,low,i,SwingLength,SwingHigh,SwingLow);
         RemoveMitigatedOrderBlocks(high[i],low[i],close[i],time[i],false);
      }
      if(ColorCandles)
      {
         CandleOpen[i]=open[i]; CandleHigh[i]=high[i];
         CandleLow[i]=low[i]; CandleClose[i]=close[i];
         CandleColorIndex[i]=(InternalBias>0 ? 0 : 1);
      }
   }

   RenderPresentStructures();
   int periodSeconds=PeriodSeconds(_Period);
   if(periodSeconds<=0) periodSeconds=60;
   DrawOrderBlockObjects(time[0],periodSeconds);
   DrawFVGs();
   AlertsArmed=true;
   if(ShowDailyLevels)
      DrawPreviousPeriodLevels(PERIOD_D1,"D",DailyLevelsStyle,DailyLevelsColor,
                               time[0],rates_total,time,high,low);
   if(ShowWeeklyLevels)
      DrawPreviousPeriodLevels(PERIOD_W1,"W",WeeklyLevelsStyle,WeeklyLevelsColor,
                               time[0],rates_total,time,high,low);
   if(ShowMonthlyLevels)
      DrawPreviousPeriodLevels(PERIOD_MN1,"M",MonthlyLevelsStyle,MonthlyLevelsColor,
                               time[0],rates_total,time,high,low);
   DrawTrailingLevels(time[0],periodSeconds);
   DrawPremiumDiscount(time[0],periodSeconds,rates_total-1);
   RefreshSetupOverlay();
   ChartRedraw(0);
   LastRatesTotal=rates_total;
   return rates_total;
}
