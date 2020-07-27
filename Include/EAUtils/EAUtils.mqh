#include <Arrays/ArrayString.mqh>

// EA parameters
int EAMagic = 10024; // EA Magic Number
bool EAEveryTick = false;

// Charting parameters
CArrayString *chartVisualCues;   // FIXME: Can replace this with "ObjectsDeleteAll or similar"

CButton btnToggleTradingEnabled;
string eaStartStopButtonName = "btnToggleTradingEnabled";

bool showChartObjects = true;
CButton btnToggleChartObjectVisibility;
string toggleChartObjectVisibilityButtonName = "btnToggleChartObjectVisibility";

CButton btnRemoveAllChartObjects;
string removeChartObjectsButtonName = "btnRemoveAllChartObjects";

bool initEAUtils() {
   chartVisualCues = new CArrayString;
   
   if (chartVisualCues == NULL) {
      Print("Failed to initEAUtils. Error: ", GetLastError());
      return false;
   }
      
   return true;
}

void deInitEAUtils() {
   toggleAllVisualCues(false);
   
   delete chartVisualCues;
}

void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam) {
   if (id == CHARTEVENT_OBJECT_CLICK) {
      // PrintFormat("You clicked on chart. lparam/x-coordinate is %d. dparam/y-coordinate is %f. sparam/object-name is %s.", lparam, dparam, sparam);
      // Comment(StringFormat("You clicked on chart. lparam/x-coordinate is %d. dparam/y-coordinate is %f. sparam/no-clue-yet is %s.", lparam, dparam, sparam));
      
      if (sparam == eaStartStopButtonName) {
         eaStartStopButtonHandler();
      } else if (sparam == toggleChartObjectVisibilityButtonName) {
         toggleChartObjectVisibilityHandler();
      } else if (sparam == removeChartObjectsButtonName) {
         removeAllChartSignalsHandler();
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


// Return true if we have enough bars to work with, else false.
bool checkBarCount() {
   int barCount = Bars(_Symbol,chartTimeframe);
   if(barCount < 60) {
      Print("EA will not activate until there are more than 60 bars. Current bar count is ", barCount, "."); // IntegerToString(barCount)
      return false;
   }
   
   return true;
}

// https://www.mql5.com/en/articles/22
//+------------------------------------------------------------------+
//| Return true if a new bar appears for the symbol/period pair      |
//+------------------------------------------------------------------+
bool isReallyNewBar() {
   //--- remember the time of opening of the last bar in the static variable
   static datetime last_time = 0;
   //--- current time
   datetime lastbar_time = (datetime) SeriesInfoInteger(Symbol(), Period(), SERIES_LASTBAR_DATE);
   
   //--- if it is the first call of the function
   if(last_time == 0) {
      //--- set time and exit
      last_time = lastbar_time;
      return(false);
   }
   
   //--- if the time is different
   if(last_time != lastbar_time) {
      //--- memorize time and return true
      last_time = lastbar_time;
      return(true);
   }
   
   //--- if we pass to this line then the bar is not new, return false
   return(false);
}
  
bool isNewBar() {
   return isReallyNewBar();

   // We will use the static previousTickTime variable to serve the bar time.
   // At each OnTick execution we will check the current bar time with the saved one.
   // If the bar time isn't equal to the saved time, it indicates that we have a new tick.
   static datetime previousTickTime;
   datetime newTickTime[1];
   bool isNewBar = false;

   // copying the last bar time to the element newTickTime[0]
   int copied = CopyTime(_Symbol, chartTimeframe, 0, 1, newTickTime);
   if(copied > 0) {
      if(previousTickTime != newTickTime[0]) {
         isNewBar = true;   // if it isn't a first call, the new bar has appeared
         previousTickTime = newTickTime[0];
      }
   } else {
      // TODO: Post to Journal
      // Alert won't trigger within strategy tester
      Alert("Error in copying historical times data, error = ", GetLastError());
      ResetLastError();
   }
   
   return isNewBar;
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
   
   return true;
}

bool createTradingButton() {
   if (!btnToggleTradingEnabled.Create(0, eaStartStopButtonName, 0, 1990, 1, 2130, 25)) {
      Print("Failed to add EA Stop/Stop button. Error code = ", GetLastError());
      return false;
   }

   ObjectSetInteger(0, eaStartStopButtonName, OBJPROP_XSIZE, 140);
   ObjectSetInteger(0, eaStartStopButtonName, OBJPROP_YSIZE, 25);
   ObjectSetInteger(0, eaStartStopButtonName, OBJPROP_CORNER, CORNER_RIGHT_UPPER); 
   ObjectSetInteger(0, eaStartStopButtonName, OBJPROP_XDISTANCE, 200);
   ObjectSetInteger(0, eaStartStopButtonName, OBJPROP_YDISTANCE, 1);
   
   updateEAStartStopButtonState();
   
   return true;
}

bool createToggleChartObjectVisibilityButton() {
   if (!btnToggleChartObjectVisibility.Create(0, toggleChartObjectVisibilityButtonName, 0, 1790, 1, 2130, 25)) {
      Print("Failed to add EA Stop/Stop button. Error code = ", GetLastError());
      return false;
   }

   ObjectSetInteger(0, toggleChartObjectVisibilityButtonName, OBJPROP_XSIZE, 140);
   ObjectSetInteger(0, toggleChartObjectVisibilityButtonName, OBJPROP_YSIZE, 25);
   ObjectSetInteger(0, toggleChartObjectVisibilityButtonName, OBJPROP_CORNER, CORNER_RIGHT_UPPER); 
   ObjectSetInteger(0, toggleChartObjectVisibilityButtonName, OBJPROP_XDISTANCE, 200);
   ObjectSetInteger(0, toggleChartObjectVisibilityButtonName, OBJPROP_YDISTANCE, 30);
   
   updateShowHideChartObjectsButtonState();
      
   return true;
}

bool createRemoveAllChartObjectsButton() {
   if (!btnRemoveAllChartObjects.Create(0, removeChartObjectsButtonName, 0, 1590, 1, 2130, 25)) {
      Print("Failed to add Remove All Signals button. Error code = ", GetLastError());
      return false;
   }
   btnRemoveAllChartObjects.Text("Delete signals");
   
   ObjectSetInteger(0, removeChartObjectsButtonName, OBJPROP_XSIZE, 140);
   ObjectSetInteger(0, removeChartObjectsButtonName, OBJPROP_YSIZE, 25);
   ObjectSetInteger(0, removeChartObjectsButtonName, OBJPROP_CORNER, CORNER_RIGHT_UPPER); 
   ObjectSetInteger(0, removeChartObjectsButtonName, OBJPROP_XDISTANCE, 200);
   ObjectSetInteger(0, removeChartObjectsButtonName, OBJPROP_YDISTANCE, 60);
      
   return true;
}

void eaStartStopButtonHandler() {
   if (enableEATrading) {
      enableEATrading = false;
      Print("EA Trading is now Off.");
    
   } else {
      enableEATrading = true;
      Print("EA Trading is now On");
   }
   
   updateEAStartStopButtonState();
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

void updateEAStartStopButtonState() {
   btnToggleTradingEnabled.Pressed(enableEATrading);
   if(enableEATrading) {
      btnToggleTradingEnabled.Text("EA Trading is Enabled");
   } else {
      btnToggleTradingEnabled.Text("EA Trading is Disabled");
   }
}

void updateShowHideChartObjectsButtonState() {
   btnToggleChartObjectVisibility.Pressed(showChartObjects);
   if(showChartObjects) {
      btnToggleChartObjectVisibility.Text("Showing price signals");
   } else {
      btnToggleChartObjectVisibility.Text("Hiding price signals");
   }
}

void toggleAllVisualCues(bool hideOnly) {
   if (!CheckPointer(chartVisualCues)==POINTER_INVALID) {
      int arraySize = chartVisualCues.Total();
      for(int i = 0; i < arraySize - 1; i++) {
         if (chartVisualCues[i] != NULL) {
            if (hideOnly) {
               if (showChartObjects) {
                  ObjectSetInteger(0, chartVisualCues[i], OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
               } else {
                  ObjectSetInteger(0, chartVisualCues[i], OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
               }
            } else {
               ObjectDelete(0, chartVisualCues[i]);
               chartVisualCues.Delete(i);
            }            
         }
      }
      
      ChartRedraw(0);
   } else {
      Print("Failed to toggle visual cues - chartVisualCues pointer is not valid.");
   }
   
   PrintFormat("Chart objects have been %s.", hideOnly ? (showChartObjects ? " made visible." : "hidden.") : "deleted.");
}

void registerChartObject(string name) {
   if(!(CheckPointer(chartVisualCues) == POINTER_INVALID) && !chartVisualCues.Add(name)) {
      PrintFormat("Failed to register new chart object called %s. It will be removed from the chart. Error: %s", name, GetLastError());
      ObjectDelete(0, name);
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
   ObjectCreate(0, labelNameEAInfoLeft, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, labelNameEAInfoLeft, OBJPROP_XDISTANCE, 50.0);
   ObjectSetInteger(0, labelNameEAInfoLeft, OBJPROP_YDISTANCE, 50.0);
   // ObjectSetString(0, labelNameEAInfoLeft, OBJPROP_FONT, "WingDings");
   ObjectSetString(0, labelNameEAInfoLeft, OBJPROP_TEXT, "Hello EA");
   
   //--- Get the maximal price of the chart
   double chart_max_price = ChartGetDouble(0, CHART_PRICE_MAX, 0);
   
   //--- Create object Label
   ObjectCreate(0, labelNameEAInfoRight, OBJ_TEXT, 0, TimeCurrent(), chart_max_price);
   //--- Set color of the text
   ObjectSetInteger(0, labelNameEAInfoRight, OBJPROP_COLOR, clrWhite);
   //--- Set background color 
   ObjectSetInteger(0, labelNameEAInfoRight, OBJPROP_BGCOLOR, clrGreen);
   //--- Set text for the Label object
   ObjectSetString(0, labelNameEAInfoRight, OBJPROP_TEXT, TimeToString(TimeCurrent()));
   //--- Set text font
   ObjectSetString(0, labelNameEAInfoRight, OBJPROP_FONT, "Trebuchet MS");
   //--- Set font size
   ObjectSetInteger(0, labelNameEAInfoRight, OBJPROP_FONTSIZE, 10);
   //--- Bind to the upper right corner
   ObjectSetInteger(0, labelNameEAInfoRight, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   //--- Rotate 90 degrees counter-clockwise
   ObjectSetDouble(0, labelNameEAInfoRight, OBJPROP_ANGLE, 90);
   //--- Forbid the selection of the object by mouse
   ObjectSetInteger(0, labelNameEAInfoRight, OBJPROP_SELECTABLE,false);
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
