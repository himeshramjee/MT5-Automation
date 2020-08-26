#include <EAUtils/CandlePatterns.mqh>

// Market data
input bool              enableMarketPushNotifications = false;   // Enable market data push notifications

CCandlePattern *candlePatterns;
input ENUM_TIMEFRAMES   candlePatternsTimeframe = PERIOD_M15;   // Chart timeframe to generate market signals
input int               emaPeriod = 20;                         // EMA period
long signalsChartID = 0;
string signalNamePrefix = "Signal:";

// Market Price quotes
MqlRates symbolPriceData[];
MqlTick latestTickPrice;         // To be used for getting recent/latest price quotes
CSymbolInfo *symbolInfo;

static int bearishPatternsFoundCounter;
static int bullishPatternsFoundCounter;

bool initMarketUtils() {
   // Grab the handle to the chart that the EA was dropped onto
   // ChartGetInteger(0, CHART_WINDOW_HANDLE, 0, signalsChartID);
   // Print("Signals Chart ID is: ", dashboardChartID);
   
   symbolInfo = new CSymbolInfo;
   symbolInfo.Name(_Symbol);
   
   candlePatterns = new CCandlePattern;
   candlePatterns.MAPeriod(emaPeriod);
   if(!candlePatterns.Init(symbolInfo, candlePatternsTimeframe, 1.0)) { return false; }
   
   // Validate and initialize the indicator data sets
   if(!candlePatterns.ValidationSettings()) { return false; }
   
   // Ensure indexing of arrays is in timeseries format, i.e. 0 = current unfinished candle to n = oldest candle
   ArraySetAsSeries(symbolPriceData, true);

   // Setup charts
   if (!setupCharts()) {
      return false;
   }

   return true;
}

void deInitMarketUtils() {
   candlePatterns.DeInitHandler();
   delete candlePatterns;
   
   delete symbolInfo;
}

bool setupCharts() {
   // Ensure the EA is on the correct timeframe
   if (ChartPeriod(signalsChartID) != candlePatternsTimeframe) {
      ChartSetSymbolPeriod(signalsChartID, _Symbol, candlePatternsTimeframe);
   }
   
   // Shift end of chart from right border
   if (!ChartGetInteger(signalsChartID, CHART_SHIFT)) {
      ChartSetInteger(signalsChartID, CHART_SHIFT, 1);
   }
   
   // Autoscroll to end of chart/current bar on each tick
   if (!ChartGetInteger(signalsChartID, CHART_AUTOSCROLL)) {
      ChartSetInteger(signalsChartID, CHART_AUTOSCROLL, 1);
   }
   
   // Add grid and period separator
   ChartSetInteger(signalsChartID, CHART_SHOW_PERIOD_SEP, true);
   ChartSetInteger(signalsChartID, CHART_SHOW_GRID, true);
   ChartSetInteger(signalsChartID, CHART_COLOR_GRID, clrGainsboro);
   
   return true;
}

bool handleMarketTickEvent() {
   if (!populateMarketData()) {
      return false;
   }
   
   if (!candlePatterns.OnTickHandler()) {
      return false;
   }
      
   checkMarketConditions();
   
   if (isNewBar()) {
      scanForBearishPriceActionPatterns();
   
      scanForBullishPriceActionPatterns();
   }
   
   return true;
}

// Return true if we have enough bars to work with, else false.
bool checkBarCount() {
   int barCount = Bars(_Symbol, candlePatternsTimeframe);
   if(barCount < 60) {
      Print("EA will not activate until there are more than 60 bars. Current bar count is ", barCount, "."); // IntegerToString(barCount)
      return false;
   }
   
   return true;
}

bool populateMarketData() {
   // Get the details of the latest x bars
   if (CopyRates(_Symbol, candlePatternsTimeframe, 0, 10, symbolPriceData) < 0) {
      PrintFormat("Error copying rates/history data - error: %d.", GetLastError());
      return false;
   }

   // Get the last price quote using the MQL5 MqlTick Structure
   if(!SymbolInfoTick(_Symbol, latestTickPrice)) {
      Alert("Error getting the latest price quote - error:", GetLastError(), ". ");
      return false;
   }
   
   return true;
}

void scanForBearishPriceActionPatterns() {
   // Scan back so patterns would've formed before time of detection/now
   int priceOffset = 1;
   
   // Price line at which to display the visual que
   double price = symbolPriceData[priceOffset].high + (200 * Point());
   // double price = latestTickPrice.bid;

   // Time line at which to display the visual que
   datetime time = symbolPriceData[priceOffset].time;
   
   bearishPatternsFoundCounter = 0;
   
   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_THREE_BLACK_CROWS)) {
      highlightPriceActionPattern("3 Black Crows", time, price, clrRed);
      bearishPatternsFoundCounter++;
   }

   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_DARK_CLOUD_COVER)) {
      highlightPriceActionPattern("Dark Cloud Cover", time, price, clrRed);
      bearishPatternsFoundCounter++;
   }

   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_BEARISH_ENGULFING)) {
      highlightPriceActionPattern("Bear Hug", time, price, clrRed);
      bearishPatternsFoundCounter++;
   }

   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_BEARISH_HARAMI)) {
      highlightPriceActionPattern("Bearish Harami", time, price, clrRed);
      bearishPatternsFoundCounter++;
   }
   
   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_EVENING_STAR)) {
      highlightPriceActionPattern("Evening Star", time, price, clrRed);
      bearishPatternsFoundCounter++;
   }

   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_EVENING_DOJI)) {
      highlightPriceActionPattern("Evening Doji", time, price, clrRed);
      bearishPatternsFoundCounter++;
   }

   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_BEARISH_MEETING_LINES)) {
      highlightPriceActionPattern("Bearish Meeting Lines", time, price, clrRed);
      bearishPatternsFoundCounter++;
   }
}

void scanForBullishPriceActionPatterns() {
   // Scan back so patterns would've formed before time of detection/now
   int priceOffset = 1;
   
   // Price line at which to display the visual que
   double price = symbolPriceData[priceOffset].high + (200 * Point());
   // double price = latestTickPrice.bid;

   // Time line at which to display the visual que
   datetime time = symbolPriceData[priceOffset].time;
   
   bullishPatternsFoundCounter = 0;
   
   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_THREE_WHITE_SOLDIERS)) {
      highlightPriceActionPattern("3 Green Soliders", time, price, clrBlue);
      bullishPatternsFoundCounter++;
   }

   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_PIERCING_LINE)) {
      highlightPriceActionPattern("Piercing Line", time, price, clrBlue);
      bullishPatternsFoundCounter++;
   }

   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_BULLISH_ENGULFING)) {
      highlightPriceActionPattern("Bullish Hug", time, price, clrBlue);
      bullishPatternsFoundCounter++;
   }

   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_BULLISH_HARAMI)) {
      highlightPriceActionPattern("Bullish Harami", time, price, clrBlue);
      bullishPatternsFoundCounter++;
   }
   
   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_MORNING_STAR)) {
      highlightPriceActionPattern("Morning Star", time, price, clrBlue);
      bullishPatternsFoundCounter++;
   }
   
   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_MORNING_DOJI)) {
      highlightPriceActionPattern("Morning Doji", time, price, clrBlue);
      bullishPatternsFoundCounter++;
   }

   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_BULLISH_MEETING_LINES)) {
      highlightPriceActionPattern("Bullish Meeting Lines", time, price, clrBlue);
      bullishPatternsFoundCounter++;
   }
}

void highlightPriceActionPattern(string name, datetime time, double price, int colour) {
   // Add a visual cue
   string visualCueUniqueName = StringFormat("%s%s (%s)(%f).", signalNamePrefix, name, TimeToString(time), price);
   price = price + (50 * Point());
   
   ChartSetInteger(signalsChartID, CHART_BRING_TO_TOP, 0, true);

   // Signal: Dark Cloud Cover near 2020.07.26 04:30 and 9222.033000
   // Signal: Bullish Meeting Lines near 2020.07.26 04:30 and 9222.033000
   
   enableMarketPushNotifications ? SendNotification(StringFormat("%s %s", _Symbol, visualCueUniqueName)) : 0;
   
   if (ObjectCreate(signalsChartID, visualCueUniqueName, OBJ_TEXT, 0, time, price)) {
      ObjectSetString(signalsChartID, visualCueUniqueName, OBJPROP_TEXT, name);
      
      ObjectSetInteger(signalsChartID, visualCueUniqueName, OBJPROP_COLOR, colour);
      // ObjectSetString(signalsChartID, visualCueUniqueName, OBJPROP_FONT, "Wingdings");
      ObjectSetInteger(signalsChartID, visualCueUniqueName, OBJPROP_FONTSIZE, 10);
      ObjectSetDouble(signalsChartID, visualCueUniqueName, OBJPROP_ANGLE, 90.0);      // rotation is clockwise if negative

      ObjectSetInteger(signalsChartID, visualCueUniqueName, OBJPROP_ANCHOR, colour == clrRed ? ANCHOR_BOTTOM : ANCHOR_TOP);      
      ObjectSetInteger(signalsChartID, visualCueUniqueName, OBJPROP_SELECTABLE, true);
      
      registerChartObject(visualCueUniqueName);
   } else {
      Print("Failed to highlight price action pattern on chart. Error: ", GetLastError());
   }
   
   // Print(visualCueUniqueName);
}

bool checkMarketConditions() {
   string marketConditionComment = StringFormat("%s trend is %s and %s. \nBearish Counter: %d\nBullish Counter: %d\nCandle is %s.", _Symbol, isBearishMarket() ? "bearish" : "not bearish", isBullishMarket() ? "bullish" : "not bullish", bearishPatternsFoundCounter, bullishPatternsFoundCounter, isCurrentCandleBearish() ? "bearish." : (isCurrentCandleBullish() ? "bullish" : "invalid."));
   Comment(marketConditionComment);
   
   return true;
}

void highlightMarketCondition(string visualCueUniqueName, ENUM_OBJECT objectType, double price, string conditionText, double angle, ENUM_ARROW_ANCHOR anchor, color objectColour) {
   // FIXME: Not a great UX.
   return;

   if (ObjectCreate(signalsChartID, signalNamePrefix + visualCueUniqueName, objectType, 0, TimeCurrent(), price)) {
      // ObjectSetString(signalsChartID, visualCueUniqueName, OBJPROP_TEXT, conditionText);
      // ObjectSetInteger(signalsChartID, visualCueUniqueName, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(signalsChartID, visualCueUniqueName, OBJPROP_ARROWCODE, 252);//236
      ObjectSetInteger(signalsChartID, visualCueUniqueName, OBJPROP_WIDTH, 3);
      ObjectSetDouble(signalsChartID, visualCueUniqueName, OBJPROP_ANGLE, angle);          // Rotate <angle> degrees counter-clockwise
      ObjectSetInteger(signalsChartID, visualCueUniqueName, OBJPROP_ANCHOR, anchor);
      ObjectSetInteger(signalsChartID, visualCueUniqueName, OBJPROP_COLOR, objectColour);
      ObjectSetInteger(signalsChartID, visualCueUniqueName, OBJPROP_STYLE, STYLE_SOLID);         // set the border line style
      ObjectSetInteger(signalsChartID, visualCueUniqueName, OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(signalsChartID, visualCueUniqueName, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(signalsChartID, visualCueUniqueName, OBJPROP_BACK, true);
      ObjectSetInteger(signalsChartID, visualCueUniqueName, OBJPROP_FILL, true);
      
      // Once the above actually flippen is working then test out setting the OBJPROP_YDISTANCE
      // ChartRedraw(0);
      
      registerChartObject(visualCueUniqueName);
   } else {
      Print("Failed to highlight market condition on chart. Error: ", GetLastError());
   }
}

bool isCurrentCandleBearish() {
   // Current price is lower than previous candles midpoint
   // return latestTickPrice.bid < candlePatterns.MidOpenClose(1);
   return latestTickPrice.bid < symbolPriceData[1].close;
}

bool isCurrentCandleBullish() {
   // Current price is higher than previous candles midpoint
   return latestTickPrice.ask > symbolPriceData[1].open;
}

bool isBearishMarket() {
   static bool bearishMarket = false;
   bool bearishMarketNow = false;

   double midpointOfPreviousBar = candlePatterns.MidOpenClose(1); // symbolPriceData[1].close;

   if (symbolPriceData[1].open > symbolPriceData[1].close         // Previous candle was Bearish
         && symbolPriceData[1].close < candlePatterns.MA(0)) {   // Previous price is below EMA
      bearishMarketNow = true;
   }
   
   if (bearishMarketNow && !bearishMarket) {
      // Print("Market Condition changed: Not Bearish -> Bearish.");
      bearishMarket = true;
      
      string visualCueUniqueName = StringFormat("%s is Bearish at %s. \nBid price: %f. \nPrev. candle Close: %f. \nEMA: %f.", _Symbol, (string)TimeCurrent(), latestTickPrice.bid, symbolPriceData[1].close, candlePatterns.MA(0));
      // enableMarketPushNotifications ? SendNotification(visualCueUniqueName) : 0;
      
      // Add a visual cue
      highlightMarketCondition(visualCueUniqueName, OBJ_ARROW, symbolPriceData[1].high /*+ (visualObjectOffsetValue * Point())*/, "Open: Bearish", 90.0, ANCHOR_TOP, clrRed);
   }
   if (!bearishMarketNow && bearishMarket) {
      // Print("Market Condition changed: Bearish -> Not Bearish.");
      bearishMarket = false;
      
      string visualCueUniqueName = StringFormat("%s no longer bearish at %s. \nAsk price: %f. \nPrev. candle Close: %f. \nEMA: %f.", _Symbol, (string)TimeCurrent(), latestTickPrice.ask, symbolPriceData[1].close, candlePatterns.MA(0));
      // enableMarketPushNotifications ? SendNotification(visualCueUniqueName) : 0; 
      
      // Add a visual cue
      highlightMarketCondition(visualCueUniqueName, OBJ_ARROW, symbolPriceData[1].low /*- (visualObjectOffsetValue * Point())*/, "Close: Bearish", 270.0, ANCHOR_TOP, clrBlack);
   }
   
   return bearishMarket;
}

bool isBullishMarket() {
   static bool bullishMarket = false;
   bool bullishMarketNow = false;
   
   double midpointOfPreviousBar = candlePatterns.MidOpenClose(1); // symbolPriceData[1].close;
      
   if (symbolPriceData[1].open < symbolPriceData[1].close         // Previous candle was bullish
         && symbolPriceData[1].close > candlePatterns.MA(0)) {    // Previous price is above EMA
      bullishMarketNow = true;
   }
   
   if (bullishMarketNow && !bullishMarket) {
      // Print("Market Condition changed: Not Bullish -> Bullish.");
      bullishMarket = true;
      
      string visualCueUniqueName = StringFormat("%s is Bullish at %s. \nAsk price: %f. \nPrev. candle Close: %f. \nEMA: %f.", _Symbol, (string)TimeCurrent(), latestTickPrice.ask, symbolPriceData[1].close, candlePatterns.MA(0));
      // enableMarketPushNotifications ? SendNotification(visualCueUniqueName) : 0;
      // Add a visual cue
      highlightMarketCondition(visualCueUniqueName, OBJ_ARROW, symbolPriceData[1].high /*+ (visualObjectOffsetValue * Point())*/, "Open: Bullish", 90.0, ANCHOR_TOP, clrBlue);
   }
   if (!bullishMarketNow && bullishMarket) {
      // Print("Market Condition changed: Bullish -> Not Bullish.");
      bullishMarket = false;
      
      string visualCueUniqueName = StringFormat("%s no longer bullish at %s. \nAsk price: %f. \nPrev. candle Close: %f. \nEMA: %f.", _Symbol, (string)TimeCurrent(), latestTickPrice.ask, symbolPriceData[1].close, candlePatterns.MA(0));
      // enableMarketPushNotifications ? SendNotification(visualCueUniqueName) : 0;
      // Add a visual cue
      highlightMarketCondition(visualCueUniqueName, OBJ_ARROW, symbolPriceData[1].low /*- (visualObjectOffsetValue * Point())*/, "Close: Bullish", 270.0, ANCHOR_TOP, clrBlack);
   }
   
   return bullishMarket;
}