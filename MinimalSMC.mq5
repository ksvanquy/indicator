#property copyright "Minimal SMC"
#property version   "1.50"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

#property indicator_label1  "Bullish BOS"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLimeGreen
#property indicator_width1  1

#property indicator_label2  "Bearish BOS"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrTomato
#property indicator_width2  1

#property indicator_label3  "Bullish CHoCH"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrAqua
#property indicator_width3  1

#property indicator_label4  "Bearish CHoCH"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrOrangeRed
#property indicator_width4  1

input int SwingLeftBars = 3;
input int SwingRightBars = 3;
input int ArrowOffsetPoints = 20;
input int OrderBlockLookbackBars = 20;
input int MaxBarsToScan = 500;
input int MaxActiveOrderBlocks = 3;
input int MaxActiveFvgs = 3;
input int FvgAtrPeriod = 14;
input double FvgMinSizeAtr = 0.15;
input ENUM_TIMEFRAMES SetupBiasTimeframe = PERIOD_H4;
input int SetupBiasLookbackBars = 500;
input int SetupMaxBarsAfterSweep = 100;
input int SetupMaxBarsToRetest = 100;
input int SetupStopBufferPoints = 20;
input double SetupMinRewardRisk = 2.0;

double BullishBosBuffer[];
double BearishBosBuffer[];
double BullishChochBuffer[];
double BearishChochBuffer[];

string ObjectPrefix = "MinimalSMC_";
datetime LastProcessedBar = 0;
string MitigatedZoneNames[];
bool BiasHistoryWarningLogged = false;

bool ShowBos = true;
bool ShowChoch = true;
bool ShowSetup = true;
bool ShowOrderBlocks = true;
bool ShowFvgs = true;
int BosColorSet = 0;
int ChochColorSet = 0;
int SetupColorSet = 0;
int ObColorSet = 0;
int FvgColorSet = 0;
string CurrentTrend = "NEUTRAL";
color CurrentTrendColor = clrSilver;
string CurrentBias = "NEUTRAL";
color CurrentBiasColor = clrSilver;

struct PendingSetupState
{
   bool bullish;
   bool active;
   bool touched;
   int breakBar;
   datetime obTime;
   datetime breakTime;
   double upperPrice;
   double lowerPrice;
   double sweepExtreme;
};

color FeatureColor(const string feature, const bool bullish)
{
   if(feature == "BOS")
   {
      if(bullish)
      {
         if(BosColorSet == 1) return clrDodgerBlue;
         if(BosColorSet == 2) return clrLimeGreen;
         if(BosColorSet == 3) return clrYellow;
         if(BosColorSet == 4) return clrWhite;
         return clrLimeGreen;
      }
      if(BosColorSet == 1) return clrMagenta;
      if(BosColorSet == 2) return clrOrangeRed;
      if(BosColorSet == 3) return clrDeepSkyBlue;
      if(BosColorSet == 4) return clrTomato;
      return clrTomato;
   }

   if(feature == "CHoCH")
   {
      if(bullish)
      {
         if(ChochColorSet == 1) return clrDeepSkyBlue;
         if(ChochColorSet == 2) return clrLimeGreen;
         if(ChochColorSet == 3) return clrGold;
         if(ChochColorSet == 4) return clrWhite;
         return clrAqua;
      }
      if(ChochColorSet == 1) return clrViolet;
      if(ChochColorSet == 2) return clrOrangeRed;
      if(ChochColorSet == 3) return clrDodgerBlue;
      if(ChochColorSet == 4) return clrTomato;
      return clrOrangeRed;
   }

   if(feature == "SETUP")
   {
      if(SetupColorSet == 1) return bullish ? clrDodgerBlue : clrMagenta;
      if(SetupColorSet == 2) return bullish ? clrAqua : clrOrangeRed;
      if(SetupColorSet == 3) return bullish ? clrWhite : clrGold;
      if(SetupColorSet == 4) return bullish ? clrYellow : clrViolet;
      return bullish ? clrLimeGreen : clrTomato;
   }

   if(feature == "OB")
   {
      if(bullish)
      {
         if(ObColorSet == 1) return C'55,75,95';
         if(ObColorSet == 2) return C'55,85,55';
         if(ObColorSet == 3) return C'90,75,45';
         if(ObColorSet == 4) return C'75,55,85';
         return C'115,115,115';
      }
      if(ObColorSet == 1) return C'95,55,75';
      if(ObColorSet == 2) return C'95,60,50';
      if(ObColorSet == 3) return C'55,75,95';
      if(ObColorSet == 4) return C'90,75,45';
      return C'135,135,135';
   }

   if(feature == "FVG")
   {
      if(bullish)
      {
         if(FvgColorSet == 1) return C'45,65,85';
         if(FvgColorSet == 2) return C'45,75,45';
         if(FvgColorSet == 3) return C'80,65,40';
         if(FvgColorSet == 4) return C'70,50,80';
         return C'70,70,70';
      }
      if(FvgColorSet == 1) return C'85,45,65';
      if(FvgColorSet == 2) return C'85,50,40';
      if(FvgColorSet == 3) return C'45,65,85';
      if(FvgColorSet == 4) return C'80,65,40';
      return C'90,90,90';
   }

   return clrSilver;
}

bool FeatureEnabled(const string objectName)
{
   if(StringFind(objectName, ObjectPrefix + "BOS_") == 0)
      return ShowBos;
   if(StringFind(objectName, ObjectPrefix + "CHoCH_") == 0)
      return ShowChoch;
   if(StringFind(objectName, ObjectPrefix + "Setup_") == 0)
      return ShowSetup;
   if(StringFind(objectName, ObjectPrefix + "OB_") == 0)
      return ShowOrderBlocks;
   if(StringFind(objectName, ObjectPrefix + "FVG_") == 0)
      return ShowFvgs;
   return true;
}

void SetObjectVisible(const string objectName, const bool visible)
{
   if(ObjectFind(0, objectName) < 0)
      return;

   long periods = visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
   if(ObjectGetInteger(0, objectName, OBJPROP_TIMEFRAMES) != periods)
      ObjectSetInteger(0, objectName, OBJPROP_TIMEFRAMES, periods);
}

void ApplyFeatureVisibility()
{
   for(int objectIndex = ObjectsTotal(0) - 1; objectIndex >= 0; --objectIndex)
   {
      string objectName = ObjectName(0, objectIndex);
      if(StringFind(objectName, ObjectPrefix) != 0 ||
         StringFind(objectName, ObjectPrefix + "Panel_") == 0)
         continue;
      SetObjectVisible(objectName, FeatureEnabled(objectName));
   }

   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, ShowBos ? DRAW_ARROW : DRAW_NONE);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, ShowBos ? DRAW_ARROW : DRAW_NONE);
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, ShowChoch ? DRAW_ARROW : DRAW_NONE);
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, ShowChoch ? DRAW_ARROW : DRAW_NONE);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, FeatureColor("BOS", true));
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, FeatureColor("BOS", false));
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, FeatureColor("CHoCH", true));
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, FeatureColor("CHoCH", false));
}

void ApplyFeatureColors()
{
   for(int objectIndex = ObjectsTotal(0) - 1; objectIndex >= 0; --objectIndex)
   {
      string objectName = ObjectName(0, objectIndex);
      if(StringFind(objectName, ObjectPrefix) != 0 ||
         StringFind(objectName, ObjectPrefix + "Panel_") == 0)
         continue;

      bool bullish = StringFind(objectName, "Bull_") >= 0 ||
                     StringFind(objectName, "_Buy_") >= 0;
      if(StringFind(objectName, ObjectPrefix + "BOS_") == 0)
         ObjectSetInteger(0, objectName, OBJPROP_COLOR, FeatureColor("BOS", bullish));
      else if(StringFind(objectName, ObjectPrefix + "CHoCH_") == 0)
         ObjectSetInteger(0, objectName, OBJPROP_COLOR, FeatureColor("CHoCH", bullish));
      else if(StringFind(objectName, ObjectPrefix + "Setup_") == 0 &&
              (StringFind(objectName, "_Arrow") >= 0 ||
               StringFind(objectName, "_Label") >= 0))
         ObjectSetInteger(0, objectName, OBJPROP_COLOR,
                          FeatureColor("SETUP", bullish));
      else if(StringFind(objectName, ObjectPrefix + "OB_") == 0)
         ObjectSetInteger(0, objectName, OBJPROP_COLOR,
                          StringFind(objectName, "_Text_") >= 0
                          ? clrWhite : FeatureColor("OB", bullish));
      else if(StringFind(objectName, ObjectPrefix + "FVG_") == 0)
         ObjectSetInteger(0, objectName, OBJPROP_COLOR,
                          StringFind(objectName, "_Text_") >= 0
                          ? clrWhite : FeatureColor("FVG", bullish));
   }

   PlotIndexSetInteger(0, PLOT_LINE_COLOR, FeatureColor("BOS", true));
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, FeatureColor("BOS", false));
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, FeatureColor("CHoCH", true));
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, FeatureColor("CHoCH", false));
}

void CreatePanelButton(const string name,
                       const string text,
                       const int x,
                       const int y,
                       const int width,
                       const color background)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 20);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, background);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void UpdatePanel()
{
   string panelName = ObjectPrefix + "Panel_Background";
   if(ObjectFind(0, panelName) < 0)
      ObjectCreate(0, panelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, panelName, OBJPROP_XSIZE, 210);
   ObjectSetInteger(0, panelName, OBJPROP_YSIZE, 200);
   ObjectSetInteger(0, panelName, OBJPROP_BGCOLOR, C'25,25,25');
   ObjectSetInteger(0, panelName, OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, panelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, panelName, OBJPROP_BACK, false);
   ObjectSetInteger(0, panelName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, panelName, OBJPROP_HIDDEN, true);

   string titleName = ObjectPrefix + "Panel_Title";
   if(ObjectFind(0, titleName) < 0)
      ObjectCreate(0, titleName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, titleName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, titleName, OBJPROP_XDISTANCE, 18);
   ObjectSetInteger(0, titleName, OBJPROP_YDISTANCE, 24);
   ObjectSetInteger(0, titleName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, titleName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, titleName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, titleName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, titleName, OBJPROP_TEXT, "SMC Trend Setup");

   string features[5] = {"BOS", "CHoCH", "Setup", "OB", "FVG"};
   string ids[5] = {"BOS", "CHoCH", "Setup", "OB", "FVG"};
   bool enabled[5] = {ShowBos, ShowChoch, ShowSetup, ShowOrderBlocks, ShowFvgs};
   color swatches[5] = {
      FeatureColor("BOS", true),
      FeatureColor("CHoCH", true),
      FeatureColor("SETUP", true),
      FeatureColor("OB", true),
      FeatureColor("FVG", true)
   };

   for(int row = 0; row < 5; ++row)
   {
      int y = 45 + row * 22;
      string toggleName = ObjectPrefix + "Panel_Toggle_" + ids[row];
      string colorName = ObjectPrefix + "Panel_Color_" + ids[row];
      CreatePanelButton(toggleName, features[row] + (enabled[row] ? "  ON" : "  OFF"),
                        16, y, 126, enabled[row] ? C'35,80,45' : C'90,40,40');
      CreatePanelButton(colorName, "Color", 148, y, 58, swatches[row]);
   }

   string trendName = ObjectPrefix + "Panel_Trend";
   if(ObjectFind(0, trendName) < 0)
      ObjectCreate(0, trendName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, trendName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, trendName, OBJPROP_XDISTANCE, 18);
   ObjectSetInteger(0, trendName, OBJPROP_YDISTANCE, 179);
   ObjectSetInteger(0, trendName, OBJPROP_COLOR, CurrentTrendColor);
   ObjectSetInteger(0, trendName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, trendName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, trendName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, trendName, OBJPROP_TEXT, "Trend: " + CurrentTrend);

   string biasName = ObjectPrefix + "Panel_Bias";
   if(ObjectFind(0, biasName) < 0)
      ObjectCreate(0, biasName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, biasName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, biasName, OBJPROP_XDISTANCE, 18);
   ObjectSetInteger(0, biasName, OBJPROP_YDISTANCE, 195);
   ObjectSetInteger(0, biasName, OBJPROP_COLOR, CurrentBiasColor);
   ObjectSetInteger(0, biasName, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, biasName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, biasName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, biasName, OBJPROP_TEXT,
                   EnumToString(SetupBiasTimeframe) + " bias: " + CurrentBias);
}

void SetTrendDisplay(const int structureTrend,
                     const double previousSwingHigh,
                     const double previousSwingLow,
                     const bool hasPreviousSwingHigh,
                     const bool hasPreviousSwingLow,
                     const double lastSwingHigh,
                     const double lastSwingLow)
{
   CurrentTrend = "NEUTRAL";
   CurrentTrendColor = clrSilver;

   if(structureTrend > 0 && hasPreviousSwingHigh && hasPreviousSwingLow &&
      lastSwingHigh > previousSwingHigh && lastSwingLow > previousSwingLow)
   {
      CurrentTrend = "BULLISH";
      CurrentTrendColor = clrLimeGreen;
   }
   else if(structureTrend < 0 && hasPreviousSwingHigh && hasPreviousSwingLow &&
           lastSwingHigh < previousSwingHigh && lastSwingLow < previousSwingLow)
   {
      CurrentTrend = "BEARISH";
      CurrentTrendColor = clrTomato;
   }

   string trendName = ObjectPrefix + "Panel_Trend";
   if(ObjectFind(0, trendName) >= 0)
   {
      ObjectSetInteger(0, trendName, OBJPROP_COLOR, CurrentTrendColor);
      ObjectSetString(0, trendName, OBJPROP_TEXT, "Trend: " + CurrentTrend);
   }
}

void SetBiasDisplay(const int bias)
{
   CurrentBias = bias > 0 ? "BULLISH" : bias < 0 ? "BEARISH" : "NEUTRAL";
   CurrentBiasColor = bias > 0 ? clrLimeGreen : bias < 0 ? clrTomato : clrSilver;
   string biasName = ObjectPrefix + "Panel_Bias";
   if(ObjectFind(0, biasName) >= 0)
   {
      ObjectSetInteger(0, biasName, OBJPROP_COLOR, CurrentBiasColor);
      ObjectSetString(0, biasName, OBJPROP_TEXT,
                      EnumToString(SetupBiasTimeframe) + " bias: " + CurrentBias);
   }
}

void CycleFeatureColor(const string feature)
{
   if(feature == "BOS") BosColorSet = (BosColorSet + 1) % 5;
   else if(feature == "CHoCH") ChochColorSet = (ChochColorSet + 1) % 5;
   else if(feature == "SETUP") SetupColorSet = (SetupColorSet + 1) % 5;
   else if(feature == "OB") ObColorSet = (ObColorSet + 1) % 5;
   else if(feature == "FVG") FvgColorSet = (FvgColorSet + 1) % 5;
}

bool WasZoneMitigated(const string zoneName)
{
   for(int index = 0; index < ArraySize(MitigatedZoneNames); ++index)
   {
      if(MitigatedZoneNames[index] == zoneName)
         return true;
   }
   return false;
}

void RememberMitigatedZone(const string zoneName)
{
   if(WasZoneMitigated(zoneName))
      return;

   int count = ArraySize(MitigatedZoneNames);
   ArrayResize(MitigatedZoneNames, count + 1);
   MitigatedZoneNames[count] = zoneName;
}

void DrawBreak(const bool bullish,
               const datetime swingTime,
               const datetime breakTime,
               const double level,
               const string label,
               const color lineColor)
{
   if((label == "BOS" && !ShowBos) || (label == "CHoCH" && !ShowChoch))
      return;

   string direction = bullish ? "Bull_" : "Bear_";
   string stamp = IntegerToString((long)breakTime);
   string lineName = ObjectPrefix + label + "_" + direction + "Line_" + stamp;
   string textName = ObjectPrefix + label + "_" + direction + "Text_" + stamp;
   bool createLine = ObjectFind(0, lineName) < 0;
   bool createText = ObjectFind(0, textName) < 0;
   color currentColor = FeatureColor(label, bullish);

   if(createLine)
   {
      if(!ObjectCreate(0, lineName, OBJ_TREND, 0, swingTime, level, breakTime, level))
         return;
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lineName, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, currentColor);

   double textPrice = level + (bullish ? 1.0 : -1.0) * ArrowOffsetPoints * _Point;
   if(createText)
   {
      if(!ObjectCreate(0, textName, OBJ_TEXT, 0, breakTime, textPrice))
         return;
      ObjectSetString(0, textName, OBJPROP_TEXT, label);
      ObjectSetString(0, textName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, textName, OBJPROP_ANCHOR, bullish ? ANCHOR_LOWER : ANCHOR_UPPER);
      ObjectSetInteger(0, textName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, textName, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, textName, OBJPROP_COLOR, currentColor);
   SetObjectVisible(lineName, FeatureEnabled(lineName));
   SetObjectVisible(textName, FeatureEnabled(textName));
}

void DrawZone(const string kind,
              const datetime startTime,
              const datetime formedTime,
              const double upperPrice,
              const double lowerPrice,
              const string label,
              const color zoneColor)
{
   bool isOb = StringFind(kind, "OB_") == 0;
   bool bullish = StringFind(kind, "Bull") >= 0;
   if((isOb && !ShowOrderBlocks) || (!isOb && !ShowFvgs))
      return;

   color currentColor = FeatureColor(isOb ? "OB" : "FVG", bullish);
   string stamp = IntegerToString((long)startTime) + "_" +
                  IntegerToString((long)formedTime);
   string zoneName = ObjectPrefix + kind + "_Zone_" + stamp;
   string textName = ObjectPrefix + kind + "_Text_" + stamp;

   if(ObjectFind(0, zoneName) < 0 && WasZoneMitigated(zoneName))
      return;

   if(ObjectFind(0, zoneName) < 0)
   {
      if(!ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0,
                       startTime, upperPrice, formedTime, lowerPrice))
         return;
      ObjectSetInteger(0, zoneName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, zoneName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, zoneName, OBJPROP_FILL, true);
      ObjectSetInteger(0, zoneName, OBJPROP_BACK, true);
      ObjectSetInteger(0, zoneName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, zoneName, OBJPROP_HIDDEN, true);
      ObjectSetString(0, zoneName, OBJPROP_TOOLTIP,
                      IntegerToString((long)formedTime));
   }

   if(ObjectFind(0, textName) < 0)
   {
      double textPrice = (upperPrice + lowerPrice) / 2.0;
      datetime textTime = (datetime)(((long)startTime + (long)formedTime) / 2);
      if(!ObjectCreate(0, textName, OBJ_TEXT, 0, textTime, textPrice))
         return;
      ObjectSetString(0, textName, OBJPROP_TEXT, label);
      ObjectSetString(0, textName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, textName, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, textName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, textName, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, zoneName, OBJPROP_COLOR, currentColor);
   ObjectSetInteger(0, textName, OBJPROP_COLOR, clrWhite);
   SetObjectVisible(zoneName, true);
   SetObjectVisible(textName, true);
}

void ApplyNearestVisibility(const string requiredPrefix,
                            const string requiredMarker,
                            const int maxVisible,
                            const double referencePrice,
                            const bool isZone)
{
   string names[];
   double distances[];
   int count = 0;

   for(int objectIndex = ObjectsTotal(0) - 1; objectIndex >= 0; --objectIndex)
   {
      string objectName = ObjectName(0, objectIndex);
      if(StringFind(objectName, requiredPrefix) != 0 ||
         StringFind(objectName, requiredMarker) < 0)
         continue;

      double price1 = ObjectGetDouble(0, objectName, OBJPROP_PRICE, 0);
      double distance = MathAbs(referencePrice - price1);
      if(isZone)
      {
         double price2 = ObjectGetDouble(0, objectName, OBJPROP_PRICE, 1);
         double upperPrice = MathMax(price1, price2);
         double lowerPrice = MathMin(price1, price2);
         if(referencePrice >= lowerPrice && referencePrice <= upperPrice)
            distance = 0.0;
         else
            distance = MathMin(MathAbs(referencePrice - upperPrice),
                               MathAbs(referencePrice - lowerPrice));
      }

      ArrayResize(names, count + 1);
      ArrayResize(distances, count + 1);
      names[count] = objectName;
      distances[count] = distance;
      ++count;
   }

   int visibleCount = (int)MathMin(MathMax(maxVisible, 0), count);
   bool selected[];
   ArrayResize(selected, count);
   ArrayInitialize(selected, false);

   for(int rank = 0; rank < visibleCount; ++rank)
   {
      int nearestIndex = -1;
      double nearestDistance = 1.7976931348623157e+308;
      for(int index = 0; index < count; ++index)
      {
         if(!selected[index] && distances[index] < nearestDistance)
         {
            nearestIndex = index;
            nearestDistance = distances[index];
         }
      }

      if(nearestIndex < 0)
         break;

      selected[nearestIndex] = true;
      string companionName = names[nearestIndex];
      if(isZone)
         StringReplace(companionName, "_Zone_", "_Text_");
      else
         StringReplace(companionName, "_Line_", "_Text_");

      SetObjectVisible(names[nearestIndex], true);
      SetObjectVisible(companionName, FeatureEnabled(companionName));
      SetObjectVisible(names[nearestIndex], FeatureEnabled(names[nearestIndex]));
   }

   for(int index = 0; index < count; ++index)
   {
      if(selected[index])
         continue;

      string companionName = names[index];
      if(isZone)
         StringReplace(companionName, "_Zone_", "_Text_");
      else
         StringReplace(companionName, "_Line_", "_Text_");

      SetObjectVisible(names[index], false);
      SetObjectVisible(companionName, false);
   }
}

void ApplyNearestLimits(const double referencePrice)
{
   ApplyNearestVisibility(ObjectPrefix + "OB_", "_Zone_",
                          MaxActiveOrderBlocks, referencePrice, true);
   ApplyNearestVisibility(ObjectPrefix + "FVG_", "_Zone_",
                          MaxActiveFvgs, referencePrice, true);
}

bool IsZoneMitigated(const bool bullishFvg,
                     const bool bearishFvg,
                     const bool bullishOb,
                     const bool bearishOb,
                     const double upperPrice,
                     const double lowerPrice,
                     const int bar,
                     const double &high[],
                     const double &low[],
                     const double &close[])
{
   if(bullishFvg)
      return low[bar] <= lowerPrice;
   if(bearishFvg)
      return high[bar] >= upperPrice;
   if(bullishOb)
      return close[bar] < lowerPrice;
   if(bearishOb)
      return close[bar] > upperPrice;

   return false;
}

void UpdateZones(const int rates_total,
                 const datetime &time[],
                 const double &high[],
                 const double &low[],
                 const double &close[])
{
   for(int objectIndex = ObjectsTotal(0) - 1; objectIndex >= 0; --objectIndex)
   {
      string zoneName = ObjectName(0, objectIndex);
      if(StringFind(zoneName, ObjectPrefix) != 0 ||
         StringFind(zoneName, "_Zone_") < 0)
         continue;

      bool bullishFvg = StringFind(zoneName, ObjectPrefix + "FVG_Bull_Zone_") == 0;
      bool bearishFvg = StringFind(zoneName, ObjectPrefix + "FVG_Bear_Zone_") == 0;
      bool bullishOb = StringFind(zoneName, ObjectPrefix + "OB_Bull_Zone_") == 0;
      bool bearishOb = StringFind(zoneName, ObjectPrefix + "OB_Bear_Zone_") == 0;
      if(!bullishFvg && !bearishFvg && !bullishOb && !bearishOb)
         continue;

      datetime formedTime =
         (datetime)StringToInteger(ObjectGetString(0, zoneName, OBJPROP_TOOLTIP));
      int formedIndex = -1;
      int endIndex = -1;
      datetime endTime = (datetime)ObjectGetInteger(0, zoneName, OBJPROP_TIME, 1);

      for(int bar = 0; bar < rates_total; ++bar)
      {
         if(time[bar] == formedTime)
            formedIndex = bar;
         if(time[bar] == endTime)
            endIndex = bar;
         if(formedIndex >= 0 && endIndex >= 0)
            break;
      }
      if(formedIndex < 0)
         continue;

      double price1 = ObjectGetDouble(0, zoneName, OBJPROP_PRICE, 0);
      double price2 = ObjectGetDouble(0, zoneName, OBJPROP_PRICE, 1);
      double upperPrice = MathMax(price1, price2);
      double lowerPrice = MathMin(price1, price2);
      bool isMitigated = false;
      datetime newEndTime = endTime;

      int firstBarToCheck = endIndex >= 0
                            ? (endTime == formedTime ? formedIndex - 1 : endIndex)
                            : formedIndex - 1;
      for(int bar = firstBarToCheck; bar >= 1; --bar)
      {
         if(IsZoneMitigated(bullishFvg, bearishFvg, bullishOb, bearishOb,
                            upperPrice, lowerPrice, bar, high, low, close))
         {
            isMitigated = true;
            newEndTime = time[bar];
            break;
         }
      }

      if(isMitigated)
      {
         string textName = zoneName;
         StringReplace(textName, "_Zone_", "_Text_");
         RememberMitigatedZone(zoneName);
         ObjectDelete(0, textName);
         ObjectDelete(0, zoneName);
         continue;
      }

      newEndTime = time[0];

      if(newEndTime != endTime)
         ObjectMove(0, zoneName, 1, newEndTime, price2);

      string textName = zoneName;
      StringReplace(textName, "_Zone_", "_Text_");
      if(ObjectFind(0, textName) >= 0)
      {
         datetime startTime =
            (datetime)ObjectGetInteger(0, zoneName, OBJPROP_TIME, 0);
         datetime textTime = (datetime)(((long)startTime + (long)newEndTime) / 2);
         double textPrice = (upperPrice + lowerPrice) / 2.0;
         ObjectMove(0, textName, 0, textTime, textPrice);
      }
   }
}

int OnInit()
{
   if(SwingLeftBars < 1 || SwingRightBars < 1 ||
      ArrowOffsetPoints < 0 || OrderBlockLookbackBars < 1 || MaxBarsToScan < 1 ||
      MaxActiveOrderBlocks < 0 || MaxActiveFvgs < 0 ||
      FvgAtrPeriod < 1 || FvgMinSizeAtr < 0.0 ||
      SetupBiasLookbackBars < 20 || SetupMaxBarsAfterSweep < 1 ||
      SetupMaxBarsToRetest < 1 || SetupStopBufferPoints < 0 ||
      SetupMinRewardRisk <= 0.0)
      return INIT_PARAMETERS_INCORRECT;

   ArrayResize(MitigatedZoneNames, 0);
   SetIndexBuffer(0, BullishBosBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, BearishBosBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, BullishChochBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, BearishChochBuffer, INDICATOR_DATA);
   ArraySetAsSeries(BullishBosBuffer, true);
   ArraySetAsSeries(BearishBosBuffer, true);
   ArraySetAsSeries(BullishChochBuffer, true);
   ArraySetAsSeries(BearishChochBuffer, true);

   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(1, PLOT_ARROW, 234);
   PlotIndexSetInteger(2, PLOT_ARROW, 233);
   PlotIndexSetInteger(3, PLOT_ARROW, 234);
   for(int plot = 0; plot < 4; ++plot)
      PlotIndexSetDouble(plot, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   IndicatorSetString(INDICATOR_SHORTNAME,
                      "SMC Trend Setup (Sweep/CHoCH/OB)");

   UpdatePanel();
   ApplyFeatureVisibility();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, ObjectPrefix);
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK ||
      StringFind(sparam, ObjectPrefix + "Panel_") != 0)
      return;

   if(sparam == ObjectPrefix + "Panel_Toggle_BOS")
      ShowBos = !ShowBos;
   else if(sparam == ObjectPrefix + "Panel_Toggle_CHoCH")
      ShowChoch = !ShowChoch;
   else if(sparam == ObjectPrefix + "Panel_Toggle_Setup")
      ShowSetup = !ShowSetup;
   else if(sparam == ObjectPrefix + "Panel_Toggle_OB")
      ShowOrderBlocks = !ShowOrderBlocks;
   else if(sparam == ObjectPrefix + "Panel_Toggle_FVG")
      ShowFvgs = !ShowFvgs;
   else if(sparam == ObjectPrefix + "Panel_Color_BOS")
      CycleFeatureColor("BOS");
   else if(sparam == ObjectPrefix + "Panel_Color_CHoCH")
      CycleFeatureColor("CHoCH");
   else if(sparam == ObjectPrefix + "Panel_Color_Setup")
      CycleFeatureColor("SETUP");
   else if(sparam == ObjectPrefix + "Panel_Color_OB")
      CycleFeatureColor("OB");
   else if(sparam == ObjectPrefix + "Panel_Color_FVG")
      CycleFeatureColor("FVG");
   else
      return;

   ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   UpdatePanel();
   ApplyFeatureColors();
   ApplyFeatureVisibility();
   ApplyNearestLimits(SymbolInfoDouble(_Symbol, SYMBOL_BID));
   ChartRedraw(0);
}

double CalculateAverageTrueRange(const int startBar,
                                 const int period,
                                 const int ratesTotal,
                                 const double &high[],
                                 const double &low[],
                                 const double &close[])
{
   if(period < 1 || startBar + period >= ratesTotal)
      return 0.0;

   double trueRangeSum = 0.0;
   for(int bar = startBar; bar < startBar + period; ++bar)
   {
      double trueRange = MathMax(high[bar] - low[bar],
                                 MathMax(MathAbs(high[bar] - close[bar + 1]),
                                         MathAbs(low[bar] - close[bar + 1])));
      trueRangeSum += trueRange;
   }

   return trueRangeSum / period;
}

bool IsFvgLargeEnough(const double gapSize,
                      const int fvgBar,
                      const int ratesTotal,
                      const double &high[],
                      const double &low[],
                      const double &close[])
{
   if(FvgMinSizeAtr <= 0.0)
      return true;

   double atr = CalculateAverageTrueRange(fvgBar + 1, FvgAtrPeriod,
                                          ratesTotal, high, low, close);
   return atr > 0.0 && gapSize >= atr * FvgMinSizeAtr;
}

int CalculateStructureBias(const MqlRates &rates[],
                           const int ratesTotal,
                           const int newestClosedBar)
{
   if(ratesTotal <= SwingLeftBars + SwingRightBars + 5)
      return 0;

   double previousHigh = 0.0;
   double latestHigh = 0.0;
   double previousLow = 0.0;
   double latestLow = 0.0;
   int highCount = 0;
   int lowCount = 0;
   bool highBroken = true;
   bool lowBroken = true;
   int lastBreakDirection = 0;
   int lastBar = (int)MathMax(newestClosedBar, 1);

   for(int bar = ratesTotal - SwingLeftBars - 1; bar >= lastBar; --bar)
   {
      if(bar + 1 < ratesTotal)
      {
         bool brokeHigh = highCount > 0 && !highBroken &&
                          rates[bar].close > latestHigh &&
                          rates[bar + 1].close <= latestHigh;
         bool brokeLow = lowCount > 0 && !lowBroken &&
                         rates[bar].close < latestLow &&
                         rates[bar + 1].close >= latestLow;

         if(brokeHigh && brokeLow)
         {
            highBroken = true;
            lowBroken = true;
            lastBreakDirection = 0;
         }
         else if(brokeHigh)
         {
            highBroken = true;
            lastBreakDirection = 1;
         }
         else if(brokeLow)
         {
            lowBroken = true;
            lastBreakDirection = -1;
         }
      }

      int pivot = bar + SwingRightBars;
      if(pivot + SwingLeftBars >= ratesTotal)
         continue;

      bool isHigh = true;
      bool isLow = true;
      for(int offset = 1; offset <= SwingLeftBars; ++offset)
      {
         if(rates[pivot].high <= rates[pivot + offset].high)
            isHigh = false;
         if(rates[pivot].low >= rates[pivot + offset].low)
            isLow = false;
      }
      for(int offset = 1; offset <= SwingRightBars; ++offset)
      {
         if(rates[pivot].high <= rates[pivot - offset].high)
            isHigh = false;
         if(rates[pivot].low >= rates[pivot - offset].low)
            isLow = false;
      }

      if(isHigh)
      {
         previousHigh = latestHigh;
         latestHigh = rates[pivot].high;
         ++highCount;
         highBroken = false;
      }
      if(isLow)
      {
         previousLow = latestLow;
         latestLow = rates[pivot].low;
         ++lowCount;
         lowBroken = false;
      }
   }

   if(highCount < 2 || lowCount < 2)
      return 0;

   if(latestHigh > previousHigh && latestLow > previousLow &&
      lastBreakDirection > 0)
      return 1;
   if(latestHigh < previousHigh && latestLow < previousLow &&
      lastBreakDirection < 0)
      return -1;
   return 0;
}

double FindOpposingLiquidityTarget(const bool bullish,
                                   const double entryPrice,
                                   const int currentBar,
                                   const int ratesTotal,
                                   const double &high[],
                                   const double &low[])
{
   double target = bullish ? DBL_MAX : -DBL_MAX;
   bool foundTarget = false;

   for(int pivot = currentBar + SwingRightBars;
       pivot + SwingLeftBars < ratesTotal;
       ++pivot)
   {
      bool isTargetSwing = true;
      double level = bullish ? high[pivot] : low[pivot];
      for(int offset = 1; offset <= SwingLeftBars; ++offset)
      {
         if((bullish && level <= high[pivot + offset]) ||
            (!bullish && level >= low[pivot + offset]))
            isTargetSwing = false;
      }
      for(int offset = 1; offset <= SwingRightBars; ++offset)
      {
         if((bullish && level <= high[pivot - offset]) ||
            (!bullish && level >= low[pivot - offset]))
            isTargetSwing = false;
      }
      if(!isTargetSwing ||
         (bullish && level <= entryPrice) ||
         (!bullish && level >= entryPrice))
         continue;

      int confirmationBar = pivot - SwingRightBars;
      bool alreadyTaken = false;
      for(int bar = confirmationBar - 1; bar >= currentBar; --bar)
      {
         if((bullish && high[bar] >= level) ||
            (!bullish && low[bar] <= level))
         {
            alreadyTaken = true;
            break;
         }
      }
      if(alreadyTaken)
         continue;

      if(!foundTarget || (bullish && level < target) ||
         (!bullish && level > target))
      {
         target = level;
         foundTarget = true;
      }
   }

   return foundTarget ? target : 0.0;
}

bool CreateSetupLevel(const string name,
                      const string label,
                      const datetime signalTime,
                      const double price,
                      const color lineColor,
                      const ENUM_LINE_STYLE lineStyle)
{
   int periodSeconds = PeriodSeconds(_Period);
   datetime lineEnd = signalTime + (datetime)(periodSeconds > 0
                                              ? periodSeconds * 20
                                              : 1200);
   if(lineEnd <= signalTime)
      lineEnd = signalTime + 60;

   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_TREND, 0, signalTime, price, lineEnd, price))
      {
         PrintFormat("Failed to create setup level %s. Error=%d",
                     name, GetLastError());
         return false;
      }
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name, OBJPROP_STYLE, lineStyle);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);

   string textName = name + "_Text";
   if(ObjectFind(0, textName) < 0)
   {
      if(!ObjectCreate(0, textName, OBJ_TEXT, 0, lineEnd, price))
      {
         PrintFormat("Failed to create setup label %s. Error=%d",
                     textName, GetLastError());
         return false;
      }
      ObjectSetString(0, textName, OBJPROP_TEXT, label);
      ObjectSetString(0, textName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, textName, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, textName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, textName, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, textName, OBJPROP_COLOR, lineColor);
   SetObjectVisible(name, ShowSetup);
   SetObjectVisible(textName, ShowSetup);
   return true;
}

void DrawTradeSetup(const bool bullish,
                    const datetime signalTime,
                    const double signalHigh,
                    const double signalLow,
                    const double entryPrice,
                    const double stopPrice,
                    const double targetPrice,
                    const double rewardRisk)
{
   string direction = bullish ? "Buy_" : "Sell_";
   string stamp = IntegerToString((long)signalTime);
   string baseName = ObjectPrefix + "Setup_" + direction + stamp;
   color setupColor = FeatureColor("SETUP", bullish);

   string arrowName = baseName + "_Arrow";
   if(ObjectFind(0, arrowName) < 0)
   {
      double arrowPrice = bullish
                          ? signalLow - ArrowOffsetPoints * _Point
                          : signalHigh + ArrowOffsetPoints * _Point;
      if(!ObjectCreate(0, arrowName, OBJ_ARROW, 0, signalTime, arrowPrice))
      {
         PrintFormat("Failed to create trade setup arrow %s. Error=%d",
                     arrowName, GetLastError());
         return;
      }
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, bullish ? 233 : 234);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, arrowName, OBJPROP_ANCHOR,
                       bullish ? ANCHOR_BOTTOM : ANCHOR_TOP);
      ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, arrowName, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, arrowName, OBJPROP_COLOR, setupColor);
   SetObjectVisible(arrowName, ShowSetup);

   string setupTextName = baseName + "_Label";
   if(ObjectFind(0, setupTextName) < 0)
   {
      double textPrice = bullish
                         ? signalLow - 2.0 * ArrowOffsetPoints * _Point
                         : signalHigh + 2.0 * ArrowOffsetPoints * _Point;
      if(!ObjectCreate(0, setupTextName, OBJ_TEXT, 0, signalTime, textPrice))
      {
         PrintFormat("Failed to create trade setup text %s. Error=%d",
                     setupTextName, GetLastError());
         return;
      }
      ObjectSetString(0, setupTextName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, setupTextName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, setupTextName, OBJPROP_ANCHOR,
                       bullish ? ANCHOR_UPPER : ANCHOR_LOWER);
      ObjectSetInteger(0, setupTextName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, setupTextName, OBJPROP_HIDDEN, true);
   }
   ObjectSetString(0, setupTextName, OBJPROP_TEXT,
                   (bullish ? "BUY SETUP " : "SELL SETUP ") +
                   DoubleToString(rewardRisk, 1) + "R");
   ObjectSetInteger(0, setupTextName, OBJPROP_COLOR, setupColor);
   SetObjectVisible(setupTextName, ShowSetup);

   CreateSetupLevel(baseName + "_Entry", "Entry", signalTime, entryPrice,
                    clrDeepSkyBlue, STYLE_DASH);
   CreateSetupLevel(baseName + "_SL", "SL", signalTime, stopPrice,
                    clrTomato, STYLE_DOT);
   CreateSetupLevel(baseName + "_TP", "TP", signalTime, targetPrice,
                    clrLimeGreen, STYLE_DASH);
}

void ProcessPendingSetups(PendingSetupState &setups[],
                          const int bar,
                          const int ratesTotal,
                          const datetime &time[],
                          const double &open[],
                          const double &high[],
                          const double &low[],
                          const double &close[])
{
   for(int index = 0; index < ArraySize(setups); ++index)
   {
      if(!setups[index].active || time[bar] >= setups[index].breakTime)
         continue;

      if(setups[index].breakBar - bar > SetupMaxBarsToRetest)
      {
         setups[index].active = false;
         continue;
      }

      bool invalidated = setups[index].bullish
                         ? close[bar] < setups[index].lowerPrice
                         : close[bar] > setups[index].upperPrice;
      if(invalidated)
      {
         setups[index].active = false;
         continue;
      }

      bool touched = high[bar] >= setups[index].lowerPrice &&
                     low[bar] <= setups[index].upperPrice;
      if(touched)
         setups[index].touched = true;

      bool confirmed = setups[index].touched &&
                       (setups[index].bullish
                        ? close[bar] > open[bar] &&
                          close[bar] > setups[index].upperPrice
                        : close[bar] < open[bar] &&
                          close[bar] < setups[index].lowerPrice);
      if(!confirmed)
         continue;

      double entry = close[bar];
      double stop = setups[index].bullish
                    ? MathMin(setups[index].sweepExtreme,
                              setups[index].lowerPrice) -
                      SetupStopBufferPoints * _Point
                    : MathMax(setups[index].sweepExtreme,
                              setups[index].upperPrice) +
                      SetupStopBufferPoints * _Point;
      double target = FindOpposingLiquidityTarget(setups[index].bullish,
                                                   entry, bar, ratesTotal,
                                                   high, low);
      double risk = setups[index].bullish ? entry - stop : stop - entry;
      double reward = setups[index].bullish ? target - entry : entry - target;
      double rewardRisk = risk > 0.0 && target > 0.0 ? reward / risk : 0.0;

      if(target > 0.0 && risk > 0.0 && reward > 0.0 &&
         rewardRisk >= SetupMinRewardRisk)
         DrawTradeSetup(setups[index].bullish, time[bar], high[bar], low[bar],
                        entry, stop, target, rewardRisk);

      setups[index].active = false;
   }
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   if(rates_total <= SwingLeftBars + SwingRightBars + 2)
      return 0;

   if(prev_calculated > 0 && time[0] == LastProcessedBar)
      return rates_total;

   if(prev_calculated == 0)
   {
      ArrayInitialize(BullishBosBuffer, EMPTY_VALUE);
      ArrayInitialize(BearishBosBuffer, EMPTY_VALUE);
      ArrayInitialize(BullishChochBuffer, EMPTY_VALUE);
      ArrayInitialize(BearishChochBuffer, EMPTY_VALUE);
   }

   int scanBars = (int)MathMin(MaxBarsToScan,
                               rates_total - SwingLeftBars - SwingRightBars - 2);
   for(int bar = 0; bar <= scanBars; ++bar)
   {
      BullishBosBuffer[bar] = EMPTY_VALUE;
      BearishBosBuffer[bar] = EMPTY_VALUE;
      BullishChochBuffer[bar] = EMPTY_VALUE;
      BearishChochBuffer[bar] = EMPTY_VALUE;
   }

   double lastSwingHigh = 0.0;
   double lastSwingLow = 0.0;
   double previousSwingHigh = 0.0;
   double previousSwingLow = 0.0;
   int lastSwingHighIndex = -1;
   int lastSwingLowIndex = -1;
   bool hasPreviousSwingHigh = false;
   bool hasPreviousSwingLow = false;
   bool swingHighBroken = true;
   bool swingLowBroken = true;
   int structureTrend = 0;
   int sweepDirection = 0;
   int sweepBar = -1;
   double sweepExtreme = 0.0;
   PendingSetupState pendingSetups[];
   ArrayResize(pendingSetups, 0);

   MqlRates biasRates[];
   ArraySetAsSeries(biasRates, true);
   int biasRatesTotal = CopyRates(_Symbol, SetupBiasTimeframe, 0,
                                  SetupBiasLookbackBars, biasRates);
   if(biasRatesTotal <= SwingLeftBars + SwingRightBars + 5)
   {
      if(!BiasHistoryWarningLogged)
      {
         PrintFormat("Trend setup signals are blocked: insufficient %s history (%d bars).",
                     EnumToString(SetupBiasTimeframe), biasRatesTotal);
         BiasHistoryWarningLogged = true;
      }
   }
   else
   {
      BiasHistoryWarningLogged = false;
   }
   int currentBias = CalculateStructureBias(biasRates, biasRatesTotal, 1);
   SetBiasDisplay(currentBias);
   int cachedBiasCutoff = -1;
   int cachedBias = 0;

   // Walk from older bars to newer bars; use only closed candles for signals.
   for(int i = scanBars; i >= 1; --i)
   {
      ProcessPendingSetups(pendingSetups, i, rates_total, time,
                           open, high, low, close);

      if(sweepDirection != 0 && sweepBar - i > SetupMaxBarsAfterSweep)
      {
         sweepDirection = 0;
         sweepBar = -1;
      }

      int barBias = 0;
      int biasShift = iBarShift(_Symbol, SetupBiasTimeframe, time[i], false);
      if(biasRatesTotal > 0 && biasShift >= 0)
      {
         int biasCutoff = (int)MathMax(biasShift + 1, 1);
         if(biasCutoff < biasRatesTotal)
         {
            if(biasCutoff != cachedBiasCutoff)
            {
               cachedBias = CalculateStructureBias(biasRates,
                                                    biasRatesTotal,
                                                    biasCutoff);
               cachedBiasCutoff = biasCutoff;
            }
            barBias = cachedBias;
         }
      }

      if(i + 2 < rates_total)
      {
         double bullishGapSize = low[i] - high[i + 2];
         double bearishGapSize = low[i + 2] - high[i];
         if(bullishGapSize > 0.0 &&
            IsFvgLargeEnough(bullishGapSize, i, rates_total, high, low, close))
            DrawZone("FVG_Bull", time[i], time[i], low[i], high[i + 2],
                     "FVG", FeatureColor("FVG", true));
         else if(bearishGapSize > 0.0 &&
                 IsFvgLargeEnough(bearishGapSize, i, rates_total, high, low, close))
            DrawZone("FVG_Bear", time[i], time[i], low[i + 2], high[i],
                     "FVG", FeatureColor("FVG", false));
      }

      if(i + 1 < rates_total)
      {
         bool brokeHigh = lastSwingHighIndex >= 0 && !swingHighBroken &&
                          close[i] > lastSwingHigh && close[i + 1] <= lastSwingHigh;
         bool brokeLow = lastSwingLowIndex >= 0 && !swingLowBroken &&
                         close[i] < lastSwingLow && close[i + 1] >= lastSwingLow;

         if(brokeHigh && brokeLow)
         {
            swingHighBroken = true;
            swingLowBroken = true;
         }
         else if(brokeHigh)
         {
            string label = structureTrend < 0 ? "CHoCH" : "BOS";
            if(label == "CHoCH")
               BullishChochBuffer[i] = low[i] - ArrowOffsetPoints * _Point;
            else
               BullishBosBuffer[i] = low[i] - ArrowOffsetPoints * _Point;
            DrawBreak(true, time[lastSwingHighIndex], time[i], lastSwingHigh,
                      label, FeatureColor(label, true));

            int orderBlockIndex = -1;
            int orderBlockEnd = (int)MathMin(lastSwingHighIndex,
                                              i + OrderBlockLookbackBars);
            for(int bar = i + 1; bar <= orderBlockEnd; ++bar)
            {
               if(close[bar] < open[bar])
               {
                  orderBlockIndex = bar;
                  break;
               }
            }
            if(orderBlockIndex >= 0)
               DrawZone("OB_Bull", time[orderBlockIndex], time[i],
                        high[orderBlockIndex], low[orderBlockIndex],
                        "Bull OB", FeatureColor("OB", true));

            if(label == "CHoCH" && sweepDirection > 0 &&
               sweepBar > i && barBias > 0 && orderBlockIndex > i &&
               orderBlockIndex <= sweepBar)
            {
               int count = ArraySize(pendingSetups);
               ArrayResize(pendingSetups, count + 1);
               pendingSetups[count].bullish = true;
               pendingSetups[count].active = true;
               pendingSetups[count].touched = false;
               pendingSetups[count].breakBar = i;
               pendingSetups[count].obTime = time[orderBlockIndex];
               pendingSetups[count].breakTime = time[i];
               pendingSetups[count].upperPrice = high[orderBlockIndex];
               pendingSetups[count].lowerPrice = low[orderBlockIndex];
               pendingSetups[count].sweepExtreme = sweepExtreme;
            }
            if(label == "CHoCH" && sweepDirection != 0)
            {
               sweepDirection = 0;
               sweepBar = -1;
            }

            swingHighBroken = true;
            structureTrend = 1;
         }

         else if(brokeLow)
         {
            string label = structureTrend > 0 ? "CHoCH" : "BOS";
            if(label == "CHoCH")
               BearishChochBuffer[i] = high[i] + ArrowOffsetPoints * _Point;
            else
               BearishBosBuffer[i] = high[i] + ArrowOffsetPoints * _Point;
            DrawBreak(false, time[lastSwingLowIndex], time[i], lastSwingLow,
                      label, FeatureColor(label, false));

            int orderBlockIndex = -1;
            int orderBlockEnd = (int)MathMin(lastSwingLowIndex,
                                              i + OrderBlockLookbackBars);
            for(int bar = i + 1; bar <= orderBlockEnd; ++bar)
            {
               if(close[bar] > open[bar])
               {
                  orderBlockIndex = bar;
                  break;
               }
            }
            if(orderBlockIndex >= 0)
               DrawZone("OB_Bear", time[orderBlockIndex], time[i],
                        high[orderBlockIndex], low[orderBlockIndex],
                        "Bear OB", FeatureColor("OB", false));

            if(label == "CHoCH" && sweepDirection < 0 &&
               sweepBar > i && barBias < 0 && orderBlockIndex > i &&
               orderBlockIndex <= sweepBar)
            {
               int count = ArraySize(pendingSetups);
               ArrayResize(pendingSetups, count + 1);
               pendingSetups[count].bullish = false;
               pendingSetups[count].active = true;
               pendingSetups[count].touched = false;
               pendingSetups[count].breakBar = i;
               pendingSetups[count].obTime = time[orderBlockIndex];
               pendingSetups[count].breakTime = time[i];
               pendingSetups[count].upperPrice = high[orderBlockIndex];
               pendingSetups[count].lowerPrice = low[orderBlockIndex];
               pendingSetups[count].sweepExtreme = sweepExtreme;
            }
            if(label == "CHoCH" && sweepDirection != 0)
            {
               sweepDirection = 0;
               sweepBar = -1;
            }

            swingLowBroken = true;
            structureTrend = -1;
         }
      }

      if(lastSwingLowIndex > i && !swingLowBroken &&
         low[i] < lastSwingLow && close[i] > lastSwingLow)
      {
         sweepDirection = 1;
         sweepBar = i;
         sweepExtreme = low[i];
      }
      else if(lastSwingHighIndex > i && !swingHighBroken &&
              high[i] > lastSwingHigh && close[i] < lastSwingHigh)
      {
         sweepDirection = -1;
         sweepBar = i;
         sweepExtreme = high[i];
      }

      int pivot = i + SwingRightBars;
      if(pivot + SwingLeftBars >= rates_total)
         continue;

      bool isSwingHigh = true;
      bool isSwingLow = true;

      for(int offset = 1; offset <= SwingLeftBars; ++offset)
      {
         if(high[pivot] <= high[pivot + offset])
            isSwingHigh = false;
         if(low[pivot] >= low[pivot + offset])
            isSwingLow = false;
      }

      for(int offset = 1; offset <= SwingRightBars; ++offset)
      {
         if(high[pivot] <= high[pivot - offset])
            isSwingHigh = false;
         if(low[pivot] >= low[pivot - offset])
            isSwingLow = false;
      }

      if(isSwingHigh)
      {
         if(lastSwingHighIndex >= 0)
         {
            previousSwingHigh = lastSwingHigh;
            hasPreviousSwingHigh = true;
         }
         lastSwingHigh = high[pivot];
         lastSwingHighIndex = pivot;
         swingHighBroken = false;
      }

      if(isSwingLow)
      {
         if(lastSwingLowIndex >= 0)
         {
            previousSwingLow = lastSwingLow;
            hasPreviousSwingLow = true;
         }
         lastSwingLow = low[pivot];
         lastSwingLowIndex = pivot;
         swingLowBroken = false;
      }
   }

   SetTrendDisplay(structureTrend, previousSwingHigh, previousSwingLow,
                   hasPreviousSwingHigh, hasPreviousSwingLow,
                   lastSwingHigh, lastSwingLow);
   UpdateZones(rates_total, time, high, low, close);
   ApplyNearestLimits(close[0]);

   LastProcessedBar = time[0];
   return rates_total;
}
