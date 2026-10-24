// Draws UTC-based SMC trading sessions and ICT kill zones on the chart.
#property copyright "SMC Kill Zones UTC"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

input group "Time and history"
input int BrokerUTCOffset = 2;
input int LookbackDays = 10;

input group "Trading sessions"
input bool ShowAsianSession = true;
input color AsianSessionColor = clrDarkSlateBlue;
input int AsianSessionAlpha = 45;
input ENUM_LINE_STYLE AsianSessionLineStyle = STYLE_SOLID;
input int AsianSessionLineWidth = 1;

input bool ShowLondonSession = false;
input color LondonSessionColor = clrDarkGreen;
input int LondonSessionAlpha = 45;
input ENUM_LINE_STYLE LondonSessionLineStyle = STYLE_SOLID;
input int LondonSessionLineWidth = 1;

input bool ShowNewYorkSession = false;
input color NewYorkSessionColor = clrDarkRed;
input int NewYorkSessionAlpha = 45;
input ENUM_LINE_STYLE NewYorkSessionLineStyle = STYLE_SOLID;
input int NewYorkSessionLineWidth = 1;

input group "ICT kill zones"
input bool ShowAsianKillZone = false;
input color AsianKillZoneColor = clrSteelBlue;
input int AsianKillZoneAlpha = 65;
input ENUM_LINE_STYLE AsianKillZoneLineStyle = STYLE_SOLID;
input int AsianKillZoneLineWidth = 1;

input bool ShowLondonOpenKillZone = false;
input color LondonOpenKillZoneColor = clrSeaGreen;
input int LondonOpenKillZoneAlpha = 65;
input ENUM_LINE_STYLE LondonOpenKillZoneLineStyle = STYLE_SOLID;
input int LondonOpenKillZoneLineWidth = 1;

input bool ShowNewYorkOpenKillZone = false;
input color NewYorkOpenKillZoneColor = clrIndianRed;
input int NewYorkOpenKillZoneAlpha = 65;
input ENUM_LINE_STYLE NewYorkOpenKillZoneLineStyle = STYLE_SOLID;
input int NewYorkOpenKillZoneLineWidth = 1;

input bool ShowLondonCloseKillZone = false;
input color LondonCloseKillZoneColor = clrDarkOrange;
input int LondonCloseKillZoneAlpha = 65;
input ENUM_LINE_STYLE LondonCloseKillZoneLineStyle = STYLE_SOLID;
input int LondonCloseKillZoneLineWidth = 1;

input group "Chart control panel"
input bool ShowControlPanel = true;

string ObjectPrefix = "SMC_KillZones_UTC_";
string PanelPrefix = "SMC_KillZones_UTC_Panel_";
bool AsianSessionEnabled;
bool LondonSessionEnabled;
bool NewYorkSessionEnabled;
bool AsianKillZoneEnabled;
bool LondonOpenKillZoneEnabled;
bool NewYorkOpenKillZoneEnabled;
bool LondonCloseKillZoneEnabled;

bool CreatePanelLabel(const string name,
                      const string text,
                      const int x,
                      const int y,
                      const int fontSize,
                      const color textColor)
{
   if(ObjectFind(0, name) < 0 &&
      !ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
   {
      PrintFormat("Could not create panel label %s. Error=%d",
                  name, GetLastError());
      return false;
   }
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   return true;
}

bool CreatePanelButton(const string name,
                       const string text,
                       const int y,
                       const bool enabled,
                       const color zoneColor)
{
   if(ObjectFind(0, name) < 0 &&
      !ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0))
   {
      PrintFormat("Could not create panel button %s. Error=%d",
                  name, GetLastError());
      return false;
   }
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 14);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, 184);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 21);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR,
                    enabled ? zoneColor : clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrGray);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
   ObjectSetString(0, name, OBJPROP_TEXT,
                   text + (enabled ? "  [ON]" : "  [OFF]"));
   return true;
}

bool CreateControlPanel()
{
   if(!ShowControlPanel)
      return true;

   string background = PanelPrefix + "Background";
   if(ObjectFind(0, background) < 0 &&
      !ObjectCreate(0, background, OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
      PrintFormat("Could not create control panel background. Error=%d",
                  GetLastError());
      return false;
   }
   ObjectSetInteger(0, background, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, background, OBJPROP_XDISTANCE, 8);
   ObjectSetInteger(0, background, OBJPROP_YDISTANCE, 8);
   ObjectSetInteger(0, background, OBJPROP_XSIZE, 196);
   ObjectSetInteger(0, background, OBJPROP_YSIZE, 244);
   ObjectSetInteger(0, background, OBJPROP_BGCOLOR, C'25,25,25');
   ObjectSetInteger(0, background, OBJPROP_BORDER_COLOR, clrDimGray);
   ObjectSetInteger(0, background, OBJPROP_BACK, false);
   ObjectSetInteger(0, background, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, background, OBJPROP_HIDDEN, true);

   bool created = CreatePanelLabel(PanelPrefix + "Title",
                                   "SMC Sessions / Kill Zones",
                                   14, 13, 9, clrWhite);
   created = CreatePanelLabel(PanelPrefix + "SessionsLabel",
                              "TRADING SESSIONS", 14, 36, 8, clrSilver) &&
             created;
   created = CreatePanelButton(PanelPrefix + "AsianSession",
                               "Asian Session", 49,
                               AsianSessionEnabled, AsianSessionColor) &&
             created;
   created = CreatePanelButton(PanelPrefix + "LondonSession",
                               "London Session", 73,
                               LondonSessionEnabled, LondonSessionColor) &&
             created;
   created = CreatePanelButton(PanelPrefix + "NewYorkSession",
                               "New York Session", 97,
                               NewYorkSessionEnabled, NewYorkSessionColor) &&
             created;
   created = CreatePanelLabel(PanelPrefix + "KillZonesLabel",
                              "ICT KILL ZONES", 14, 125, 8, clrSilver) &&
             created;
   created = CreatePanelButton(PanelPrefix + "AsianKillZone",
                               "Asian Kill Zone", 138,
                               AsianKillZoneEnabled, AsianKillZoneColor) &&
             created;
   created = CreatePanelButton(PanelPrefix + "LondonOpenKillZone",
                               "London Open Kill Zone", 162,
                               LondonOpenKillZoneEnabled,
                               LondonOpenKillZoneColor) &&
             created;
   created = CreatePanelButton(PanelPrefix + "NewYorkOpenKillZone",
                               "New York Open Kill Zone", 186,
                               NewYorkOpenKillZoneEnabled,
                               NewYorkOpenKillZoneColor) &&
             created;
   created = CreatePanelButton(PanelPrefix + "LondonCloseKillZone",
                               "London Close Kill Zone", 210,
                               LondonCloseKillZoneEnabled,
                               LondonCloseKillZoneColor) &&
             created;
   return created;
}

void ToggleZone(const string buttonName)
{
   if(buttonName == PanelPrefix + "AsianSession")
      AsianSessionEnabled = !AsianSessionEnabled;
   else if(buttonName == PanelPrefix + "LondonSession")
      LondonSessionEnabled = !LondonSessionEnabled;
   else if(buttonName == PanelPrefix + "NewYorkSession")
      NewYorkSessionEnabled = !NewYorkSessionEnabled;
   else if(buttonName == PanelPrefix + "AsianKillZone")
      AsianKillZoneEnabled = !AsianKillZoneEnabled;
   else if(buttonName == PanelPrefix + "LondonOpenKillZone")
      LondonOpenKillZoneEnabled = !LondonOpenKillZoneEnabled;
   else if(buttonName == PanelPrefix + "NewYorkOpenKillZone")
      NewYorkOpenKillZoneEnabled = !NewYorkOpenKillZoneEnabled;
   else if(buttonName == PanelPrefix + "LondonCloseKillZone")
      LondonCloseKillZoneEnabled = !LondonCloseKillZoneEnabled;
   else
      return;

   CreateControlPanel();
   RefreshZonesFromHistory();
   ChartRedraw(0);
}

bool ValidStyle(const ENUM_LINE_STYLE style)
{
   return style == STYLE_SOLID || style == STYLE_DASH ||
          style == STYLE_DOT || style == STYLE_DASHDOT ||
          style == STYLE_DASHDOTDOT;
}

bool ValidZoneSettings(const int alpha,
                       const int width,
                       const ENUM_LINE_STYLE style,
                       const string zoneName)
{
   if(alpha < 0 || alpha > 255)
   {
      PrintFormat("%s alpha must be between 0 and 255.", zoneName);
      return false;
   }
   if(width < 1 || width > 5)
   {
      PrintFormat("%s line width must be between 1 and 5.", zoneName);
      return false;
   }
   if(!ValidStyle(style))
   {
      PrintFormat("%s has an unsupported line style.", zoneName);
      return false;
   }
   return true;
}

string DateKey(const datetime day)
{
   MqlDateTime parts;
   TimeToStruct(day, parts);
   return StringFormat("%04d%02d%02d", parts.year, parts.mon, parts.day);
}

void DrawZone(const bool enabled,
              const string zoneId,
              const int startHour,
              const int endHour,
              const color zoneColor,
              const int alpha,
              const ENUM_LINE_STYLE lineStyle,
              const int lineWidth,
              const int ratesTotal,
              const datetime &time[],
              const double &high[],
              const double &low[],
              const datetime latestUtcDay,
              const int lookbackDays)
{
   for(int dayIndex = 0; dayIndex < lookbackDays; ++dayIndex)
   {
      datetime utcDay = latestUtcDay - (datetime)(dayIndex * 86400);
      datetime utcStart = utcDay + (datetime)(startHour * 3600);
      datetime utcEnd = utcDay + (datetime)(endHour * 3600);
      datetime brokerStart = utcStart + (datetime)(BrokerUTCOffset * 3600);
      datetime brokerEnd = utcEnd + (datetime)(BrokerUTCOffset * 3600);
      string objectName = ObjectPrefix + zoneId + "_" + DateKey(utcDay);

      if(!enabled)
      {
         ObjectDelete(0, objectName);
         continue;
      }

      double zoneHigh = -DBL_MAX;
      double zoneLow = DBL_MAX;
      bool foundBar = false;
      datetime oldestUtcDay = latestUtcDay -
                              (datetime)((lookbackDays - 1) * 86400);

      for(int bar = 0; bar < ratesTotal; ++bar)
      {
         datetime barUtc = time[bar] - (datetime)(BrokerUTCOffset * 3600);
         if(barUtc < oldestUtcDay)
            break;
         if(barUtc < utcStart || barUtc >= utcEnd)
            continue;

         if(high[bar] > zoneHigh)
            zoneHigh = high[bar];
         if(low[bar] < zoneLow)
            zoneLow = low[bar];
         foundBar = true;
      }

      if(!foundBar)
      {
         ObjectDelete(0, objectName);
         continue;
      }

      if(ObjectFind(0, objectName) < 0 &&
         !ObjectCreate(0, objectName, OBJ_RECTANGLE, 0,
                       brokerStart, zoneHigh, brokerEnd, zoneLow))
      {
         PrintFormat("Could not create %s. Error=%d", objectName, GetLastError());
         continue;
      }

      if(!ObjectMove(0, objectName, 0, brokerStart, zoneHigh) ||
         !ObjectMove(0, objectName, 1, brokerEnd, zoneLow))
      {
         PrintFormat("Could not update %s. Error=%d", objectName, GetLastError());
         continue;
      }

      ObjectSetInteger(0, objectName, OBJPROP_COLOR,
                       (long)ColorToARGB(zoneColor, (uchar)alpha));
      ObjectSetInteger(0, objectName, OBJPROP_STYLE, lineStyle);
      ObjectSetInteger(0, objectName, OBJPROP_WIDTH, lineWidth);
      ObjectSetInteger(0, objectName, OBJPROP_FILL, true);
      ObjectSetInteger(0, objectName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objectName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objectName, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, objectName, OBJPROP_HIDDEN, true);
   }
}

void RenderZones(const int ratesTotal,
                 const datetime &time[],
                 const double &high[],
                 const double &low[],
                 const datetime latestUtcDay)
{
   DrawZone(AsianSessionEnabled, "AsianSession", 0, 9,
            AsianSessionColor, AsianSessionAlpha, AsianSessionLineStyle,
            AsianSessionLineWidth, ratesTotal, time, high, low,
            latestUtcDay, LookbackDays);
   DrawZone(LondonSessionEnabled, "LondonSession", 7, 16,
            LondonSessionColor, LondonSessionAlpha, LondonSessionLineStyle,
            LondonSessionLineWidth, ratesTotal, time, high, low,
            latestUtcDay, LookbackDays);
   DrawZone(NewYorkSessionEnabled, "NewYorkSession", 12, 21,
            NewYorkSessionColor, NewYorkSessionAlpha, NewYorkSessionLineStyle,
            NewYorkSessionLineWidth, ratesTotal, time, high, low,
            latestUtcDay, LookbackDays);
   DrawZone(AsianKillZoneEnabled, "AsianKillZone", 0, 4,
            AsianKillZoneColor, AsianKillZoneAlpha, AsianKillZoneLineStyle,
            AsianKillZoneLineWidth, ratesTotal, time, high, low,
            latestUtcDay, LookbackDays);
   DrawZone(LondonOpenKillZoneEnabled, "LondonOpenKillZone", 7, 10,
            LondonOpenKillZoneColor, LondonOpenKillZoneAlpha,
            LondonOpenKillZoneLineStyle, LondonOpenKillZoneLineWidth,
            ratesTotal, time, high, low, latestUtcDay, LookbackDays);
   DrawZone(NewYorkOpenKillZoneEnabled, "NewYorkOpenKillZone", 12, 15,
            NewYorkOpenKillZoneColor, NewYorkOpenKillZoneAlpha,
            NewYorkOpenKillZoneLineStyle, NewYorkOpenKillZoneLineWidth,
            ratesTotal, time, high, low, latestUtcDay, LookbackDays);
   DrawZone(LondonCloseKillZoneEnabled, "LondonCloseKillZone", 15, 17,
            LondonCloseKillZoneColor, LondonCloseKillZoneAlpha,
            LondonCloseKillZoneLineStyle, LondonCloseKillZoneLineWidth,
            ratesTotal, time, high, low, latestUtcDay, LookbackDays);
}

void RefreshZonesFromHistory()
{
   datetime brokerNow = TimeCurrent();
   datetime utcNow = brokerNow - (datetime)(BrokerUTCOffset * 3600);
   datetime latestUtcDay = (datetime)(((long)utcNow / 86400) * 86400);
   datetime oldestUtcDay = latestUtcDay -
                           (datetime)((LookbackDays - 1) * 86400);
   datetime brokerStart = oldestUtcDay +
                          (datetime)(BrokerUTCOffset * 3600);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, _Period, brokerStart, brokerNow, rates);
   if(copied <= 0)
   {
      PrintFormat("Could not refresh session zones from chart history. "
                  "CopyRates=%d, error=%d", copied, GetLastError());
      return;
   }

   datetime times[];
   double highs[];
   double lows[];
   ArrayResize(times, copied);
   ArrayResize(highs, copied);
   ArrayResize(lows, copied);
   ArraySetAsSeries(times, true);
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);

   for(int bar = 0; bar < copied; ++bar)
   {
      times[bar] = rates[bar].time;
      highs[bar] = rates[bar].high;
      lows[bar] = rates[bar].low;
   }

   RenderZones(copied, times, highs, lows, latestUtcDay);
}

int OnInit()
{
   if(BrokerUTCOffset < -14 || BrokerUTCOffset > 14)
   {
      Print("BrokerUTCOffset must be between -14 and 14 hours.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(LookbackDays < 1 || LookbackDays > 365)
   {
      Print("LookbackDays must be between 1 and 365.");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(!ValidZoneSettings(AsianSessionAlpha, AsianSessionLineWidth,
                         AsianSessionLineStyle, "Asian session") ||
      !ValidZoneSettings(LondonSessionAlpha, LondonSessionLineWidth,
                         LondonSessionLineStyle, "London session") ||
      !ValidZoneSettings(NewYorkSessionAlpha, NewYorkSessionLineWidth,
                         NewYorkSessionLineStyle, "New York session") ||
      !ValidZoneSettings(AsianKillZoneAlpha, AsianKillZoneLineWidth,
                         AsianKillZoneLineStyle, "Asian kill zone") ||
      !ValidZoneSettings(LondonOpenKillZoneAlpha, LondonOpenKillZoneLineWidth,
                         LondonOpenKillZoneLineStyle, "London open kill zone") ||
      !ValidZoneSettings(NewYorkOpenKillZoneAlpha, NewYorkOpenKillZoneLineWidth,
                         NewYorkOpenKillZoneLineStyle, "New York open kill zone") ||
      !ValidZoneSettings(LondonCloseKillZoneAlpha, LondonCloseKillZoneLineWidth,
                         LondonCloseKillZoneLineStyle, "London close kill zone"))
      return INIT_PARAMETERS_INCORRECT;

   AsianSessionEnabled = ShowAsianSession;
   LondonSessionEnabled = ShowLondonSession;
   NewYorkSessionEnabled = ShowNewYorkSession;
   AsianKillZoneEnabled = ShowAsianKillZone;
   LondonOpenKillZoneEnabled = ShowLondonOpenKillZone;
   NewYorkOpenKillZoneEnabled = ShowNewYorkOpenKillZone;
   LondonCloseKillZoneEnabled = ShowLondonCloseKillZone;

   ObjectsDeleteAll(0, ObjectPrefix);
   if(!CreateControlPanel())
   {
      ObjectsDeleteAll(0, ObjectPrefix);
      return INIT_FAILED;
   }
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, ObjectPrefix);
   ChartRedraw(0);
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
      ToggleZone(sparam);
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
   if(rates_total <= 0)
      return 0;

   ArraySetAsSeries(time, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   datetime latestUtc = time[0] - (datetime)(BrokerUTCOffset * 3600);
   datetime latestUtcDay = (datetime)(((long)latestUtc / 86400) * 86400);
   RenderZones(rates_total, time, high, low, latestUtcDay);

   ChartRedraw(0);
   return rates_total;
}
