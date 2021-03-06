/*
   Eventually: https://www.mql5.com/en/articles/4715
*/

#include <Arrays/ArrayString.mqh>

// EA parameters
int EAMagic = 10024; // EA Magic Number
bool EAEveryTick = false;

// Charting parameters
long dashboardChartID = -1;
CArrayString *chartVisualCues;   // FIXME: Can replace this with "ObjectsDeleteAll or similar"

CButton btnToggleTradingEnabled;
string eaStartStopButtonName = "btnToggleTradingEnabled";

bool showChartObjects = true;
CButton btnToggleChartObjectVisibility;
string toggleChartObjectVisibilityButtonName = "btnToggleChartObjectVisibility";

CButton btnRemoveAllChartObjects;
string removeChartObjectsButtonName = "btnRemoveAllChartObjects";

input bool enableDebugLogs = false;    // Enable certain debug logging
bool loggingEnabled = false;
CButton btnToggleLoggingEnabled;
string toggleLoggingEnabledButtonName = "btnToggleLoggingEnabled";

bool initEAUtils() {
   dashboardChartID = signalsChartID;
   // Print("Dashboard Chart ID is: ", dashboardChartID);
   
   loggingEnabled = enableDebugLogs;
   
   chartVisualCues = new CArrayString;
   
   if (chartVisualCues == NULL) {
      Print("Failed to initEAUtils. Error: ", GetLastError());
      return false;
   }
      
   return true;
}

void deInitEAUtils() {
   toggleAllVisualCues(false);
   
   ObjectsDeleteAll(dashboardChartID);
   
   delete chartVisualCues;
}

void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam) {
   if (id == CHARTEVENT_OBJECT_CLICK) {
      // PrintFormat("You clicked on chart. lparam/x-coordinate is %d. dparam/y-coordinate is %f. sparam/object-name is %s.", lparam, dparam, sparam);
      // Comment(StringFormat("You clicked on chart. lparam/x-coordinate is %d. dparam/y-coordinate is %f. sparam/no-clue-yet is %s.", lparam, dparam, sparam));
      
      // Call event handlers
      if (sparam == eaStartStopButtonName) {
         eaStartStopButtonHandler();
      } else if (sparam == toggleChartObjectVisibilityButtonName) {
         toggleChartObjectVisibilityHandler();
      } else if (sparam == removeChartObjectsButtonName) {
         removeAllChartSignalsHandler();
      } else if (sparam == toggleLoggingEnabledButtonName) {
         toggleLoggingEnabledHandler();
      }
   }
   
   if (id == CHARTEVENT_CHART_CHANGE) {
      // PrintFormat("You resized the chart. lparam/x-coordinate is %d. dparam/y-coordinate is %f. sparam/object-name is %s.", lparam, dparam, sparam);
   }
}

bool validateTradingPermissions() {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
      Alert("Please enable automated trading in your client terminal. Find the 'Algo/Auto Trading' button on the toolbar.");
      return false;
   }
   
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) {
      Alert("Automated trading is forbidden in the program settings for ", __FILE__);
      return false;
   }
   
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) {
      Alert("Automated trading is forbidden for the account ", AccountInfoInteger(ACCOUNT_LOGIN), " at the trade server side");
      return false;
   }
   
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) {
      Alert("Trading is not enabled for this account.");
      Comment("Trading is forbidden for the account ", AccountInfoInteger(ACCOUNT_LOGIN),
            ".\n Perhaps an investor password has been used to connect to the trading account.",
            "\n Check the terminal journal for the following entry:",
            "\n\'", AccountInfoInteger(ACCOUNT_LOGIN), "\': trading has been disabled - investor mode.");
      return false;
   }
   
   return true;
}

bool isNewDay() {
   datetime today = TimeCurrent();
   MqlDateTime alsoToday;
   TimeToStruct(today, alsoToday);
   
   static int previousDay = alsoToday.day;
   int currentDay = alsoToday.day;
   
   if (previousDay != currentDay) {
      previousDay = currentDay;
      return true;
   }
   
   return false;
}

bool isDayEnding() {
   datetime today = TimeCurrent();
   MqlDateTime alsoToday;
   TimeToStruct(today, alsoToday);
   
   int currentHour = alsoToday.hour;
   int currentMin = alsoToday.min;
   
   if (currentHour == 23 && currentMin == 59) {
      return true;
   }
   
   return false;
}

bool isNewBar() {
   // Taken from https://www.mql5.com/en/articles/22

   //--- remember the time of opening of the last bar in the static variable
   static datetime last_time = 0;
   //--- current time
   datetime lastbar_time = (datetime) SeriesInfoInteger(Symbol(), Period(), SERIES_LASTBAR_DATE);
   
   //--- if it is the first call of the function
   if(last_time == 0) {
      //--- set time and exit
      last_time = lastbar_time;
      return false;
   }
   
   //--- if the time is different
   if(last_time != lastbar_time) {
      //--- memorize time and return true
      last_time = lastbar_time;
      // Print("New bar: "+ last_time + " and last bar time is " + lastbar_time);
      return true;
   }
   
   //--- if we pass to this line then the bar is not new, return false
   // Print("\tOld bar: "+ last_time + " and last bar time is " + lastbar_time);
   return false;
}

bool createEAButtons() {
   if (!createTradingButton()) {
      return false;
   }
   
   if (!createToggleChartObjectVisibilityButton()) {
      return false;
   }
   
   if (!createRemoveAllChartObjectsButton()) {
      return false;
   }
   
   if (!createToggleLoggingEnabledButton()) {
      return false;
   }
   
   // TODO: Add chart screenshot button
   // ChartScreenShot(dashboardChartID, Symbol()+"_"+(string)Period()+".gif", 640, 480);
   
   return true;
}

bool createTradingButton() {
   if (!btnToggleTradingEnabled.Create(dashboardChartID, eaStartStopButtonName, 0, 1990, 1, 2130, 25)) {
      Print("Failed to add EA Stop/Stop button. Error code = ", GetLastError());
      return false;
   }

   ObjectSetInteger(dashboardChartID, eaStartStopButtonName, OBJPROP_XSIZE, 140);
   ObjectSetInteger(dashboardChartID, eaStartStopButtonName, OBJPROP_YSIZE, 25);
   ObjectSetInteger(dashboardChartID, eaStartStopButtonName, OBJPROP_CORNER, CORNER_RIGHT_UPPER); 
   ObjectSetInteger(dashboardChartID, eaStartStopButtonName, OBJPROP_XDISTANCE, 200);
   ObjectSetInteger(dashboardChartID, eaStartStopButtonName, OBJPROP_YDISTANCE, 1);
   
   updateTradingEnabledButtonState();
   
   return true;
}

bool createToggleChartObjectVisibilityButton() {
   if (!btnToggleChartObjectVisibility.Create(dashboardChartID, toggleChartObjectVisibilityButtonName, 0, 1790, 1, 2130, 25)) {
      Print("Failed to add EA Stop/Stop button. Error code = ", GetLastError());
      return false;
   }

   ObjectSetInteger(dashboardChartID, toggleChartObjectVisibilityButtonName, OBJPROP_XSIZE, 140);
   ObjectSetInteger(dashboardChartID, toggleChartObjectVisibilityButtonName, OBJPROP_YSIZE, 25);
   ObjectSetInteger(dashboardChartID, toggleChartObjectVisibilityButtonName, OBJPROP_CORNER, CORNER_RIGHT_UPPER); 
   ObjectSetInteger(dashboardChartID, toggleChartObjectVisibilityButtonName, OBJPROP_XDISTANCE, 200);
   ObjectSetInteger(dashboardChartID, toggleChartObjectVisibilityButtonName, OBJPROP_YDISTANCE, 30);
   
   updateShowHideChartObjectsButtonState();
      
   return true;
}

bool createRemoveAllChartObjectsButton() {
   if (!btnRemoveAllChartObjects.Create(dashboardChartID, removeChartObjectsButtonName, 0, 1590, 1, 2130, 25)) {
      Print("Failed to add Remove All Signals button. Error code = ", GetLastError());
      return false;
   }
   btnRemoveAllChartObjects.Text("Delete signals");
   
   ObjectSetInteger(dashboardChartID, removeChartObjectsButtonName, OBJPROP_XSIZE, 140);
   ObjectSetInteger(dashboardChartID, removeChartObjectsButtonName, OBJPROP_YSIZE, 25);
   ObjectSetInteger(dashboardChartID, removeChartObjectsButtonName, OBJPROP_CORNER, CORNER_RIGHT_UPPER); 
   ObjectSetInteger(dashboardChartID, removeChartObjectsButtonName, OBJPROP_XDISTANCE, 200);
   ObjectSetInteger(dashboardChartID, removeChartObjectsButtonName, OBJPROP_YDISTANCE, 60);
      
   return true;
}

bool createToggleLoggingEnabledButton() {
   if (!btnToggleLoggingEnabled.Create(dashboardChartID, toggleLoggingEnabledButtonName, 0, 1390, 1, 2130, 25)) {
      Print("Failed to add Toggle Logging button. Error code = ", GetLastError());
      return false;
   }

   ObjectSetInteger(dashboardChartID, toggleLoggingEnabledButtonName, OBJPROP_XSIZE, 140);
   ObjectSetInteger(dashboardChartID, toggleLoggingEnabledButtonName, OBJPROP_YSIZE, 25);
   ObjectSetInteger(dashboardChartID, toggleLoggingEnabledButtonName, OBJPROP_CORNER, CORNER_RIGHT_UPPER); 
   ObjectSetInteger(dashboardChartID, toggleLoggingEnabledButtonName, OBJPROP_XDISTANCE, 200);
   ObjectSetInteger(dashboardChartID, toggleLoggingEnabledButtonName, OBJPROP_YDISTANCE, 90);
   
   updateLoggingEnaledButtonState();
   
   return true;
}

void eaStartStopButtonHandler() {
   if (tradingEnabled) {
      tradingEnabled = false;
      Print("AutoTrade Off.");
    
   } else {
      tradingEnabled = true;
      Print("AutoTrade On");
   }
   
   updateTradingEnabledButtonState();
}

void toggleChartObjectVisibilityHandler() {
   if (showChartObjects) {
      showChartObjects = false;
    
   } else {
      showChartObjects = true;
   }
   
   toggleAllVisualCues(true);
   updateShowHideChartObjectsButtonState();
}

void removeAllChartSignalsHandler() {
   toggleAllVisualCues(false);
}

void toggleLoggingEnabledHandler() {
   if (loggingEnabled) {
      loggingEnabled = false;
    
   } else {
      loggingEnabled = true;
   }
   
   updateLoggingEnaledButtonState();
}

void updateTradingEnabledButtonState() {
   btnToggleTradingEnabled.Pressed(tradingEnabled);
   if(tradingEnabled) {
      btnToggleTradingEnabled.Text("AutoTrade Enabled");
   } else {
      btnToggleTradingEnabled.Text("AutoTrade Disabled");
   }
}

void updateShowHideChartObjectsButtonState() {
   btnToggleChartObjectVisibility.Pressed(showChartObjects);
   if(showChartObjects) {
      btnToggleChartObjectVisibility.Text("Showing Signals");
   } else {
      btnToggleChartObjectVisibility.Text("Hiding Signals");
   }
}

void updateLoggingEnaledButtonState() {
   btnToggleLoggingEnabled.Pressed(loggingEnabled);
   if(loggingEnabled) {
      btnToggleLoggingEnabled.Text("Logging Enabled");
   } else {
      btnToggleLoggingEnabled.Text("Logging Disabled");
   }
}

void toggleAllVisualCues(bool hideOnly) {
   if (hideOnly) {
      int arraySize = chartVisualCues.Total();
      for(int i = 0; i < arraySize - 1; i++) {
         if (showChartObjects) {
            ObjectSetInteger(dashboardChartID, chartVisualCues[i], OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
         } else {
            ObjectSetInteger(dashboardChartID, chartVisualCues[i], OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
         }
      }
      
      ChartRedraw(0);
   } else {
      ObjectsDeleteAll(dashboardChartID, signalNamePrefix);
      chartVisualCues.Clear();
   }
   
   PrintFormat("Chart objects have been %s.", hideOnly ? (showChartObjects ? " made visible." : "hidden.") : "deleted.");
}

void registerChartObject(string name) {
   if(!(CheckPointer(chartVisualCues) == POINTER_INVALID) && !chartVisualCues.Add(name)) {
      PrintFormat("Failed to register new chart object called %s. It will be removed from the chart. Error: %s", name, GetLastError());
      ObjectDelete(dashboardChartID, name);
   }
   
   chartVisualCues.Add(name);
}

/*
// *** HERE BE DRAGONS ****
*/

void showEAInfo() {
   string labelNameEAInfoLeft = "EAInfoLeft";
   string labelNameEAInfoRight = "EAInfoRight";
   
   // https://www.mql5.com/en/forum/133139
   ObjectCreate(dashboardChartID, labelNameEAInfoLeft, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(dashboardChartID, labelNameEAInfoLeft, OBJPROP_XDISTANCE, 50.0);
   ObjectSetInteger(dashboardChartID, labelNameEAInfoLeft, OBJPROP_YDISTANCE, 50.0);
   // ObjectSetString(dashboardChartID, labelNameEAInfoLeft, OBJPROP_FONT, "WingDings");
   ObjectSetString(dashboardChartID, labelNameEAInfoLeft, OBJPROP_TEXT, "Hello EA");
   
   //--- Get the maximal price of the chart
   double chart_max_price = ChartGetDouble(dashboardChartID, CHART_PRICE_MAX, 0);
   
   //--- Create object Label
   ObjectCreate(dashboardChartID, labelNameEAInfoRight, OBJ_TEXT, 0, TimeCurrent(), chart_max_price);
   //--- Set color of the text
   ObjectSetInteger(dashboardChartID, labelNameEAInfoRight, OBJPROP_COLOR, clrWhite);
   //--- Set background color 
   ObjectSetInteger(dashboardChartID, labelNameEAInfoRight, OBJPROP_BGCOLOR, clrGreen);
   //--- Set text for the Label object
   ObjectSetString(dashboardChartID, labelNameEAInfoRight, OBJPROP_TEXT, TimeToString(TimeCurrent()));
   //--- Set text font
   ObjectSetString(dashboardChartID, labelNameEAInfoRight, OBJPROP_FONT, "Trebuchet MS");
   //--- Set font size
   ObjectSetInteger(dashboardChartID, labelNameEAInfoRight, OBJPROP_FONTSIZE, 10);
   //--- Bind to the upper right corner
   ObjectSetInteger(dashboardChartID, labelNameEAInfoRight, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   //--- Rotate 90 degrees counter-clockwise
   ObjectSetDouble(dashboardChartID, labelNameEAInfoRight, OBJPROP_ANGLE, 90);
   //--- Forbid the selection of the object by mouse
   ObjectSetInteger(dashboardChartID, labelNameEAInfoRight, OBJPROP_SELECTABLE,false);
   //--- redraw object
   ChartRedraw(0);
}

void showMetaInfo() {
   //--- obtain spread from the symbol properties
   bool spreadfloat=SymbolInfoInteger(Symbol(),SYMBOL_SPREAD_FLOAT);
   string comm=StringFormat("%s spread = %I64d points. ", spreadfloat?"floating":"fixed", SymbolInfoInteger(Symbol(),SYMBOL_SPREAD));
   //--- now let's calculate the spread by ourselves
   double ask=SymbolInfoDouble(Symbol(),SYMBOL_ASK);
   double bid=SymbolInfoDouble(Symbol(),SYMBOL_BID);
   double spread=ask-bid;
   int spread_points=(int)MathRound(spread/SymbolInfoDouble(Symbol(),SYMBOL_POINT));
   comm=comm+"Calculated spread = "+(string)spread_points+" points.";
   Print(comm);
}
