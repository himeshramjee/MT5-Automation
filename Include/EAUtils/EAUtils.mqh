//+------------------------------------------------------------------+
//|                                                      EAUtils.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

// EA parameters
int EAMagic = 10024; // EA Magic Number

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
   int barCount = Bars(_Symbol,_Period);
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
   int copied = CopyTime(_Symbol,_Period, 0, 1, newTickTime);
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

/*
// *** HERE BE DRAGONS ****
*/

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
