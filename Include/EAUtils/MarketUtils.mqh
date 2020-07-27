#include <EAUtils/CandlePatterns.mqh>

// Market data
input bool              enableMarketPushNotifications = true;        // Enable market data push notifications

CCandlePattern *candlePatterns;
input ENUM_TIMEFRAMES   candlePatternsTimeframe = PERIOD_M15;             // Chart timeframe to generate market signals

// EMA Indicator
input int               emaPeriod = 20;                         // EMA period

int                     emaIndicatorHandle = INVALID_HANDLE;
double                  emaData[];

// Market Price quotes
MqlRates symbolPriceData[];
MqlTick latestTickPrice;         // To be used for getting recent/latest price quotes
CSymbolInfo *symbolInfo;

static int bearishPatternsFoundCounter;
static int bullishPatternsFoundCounter;

bool initMarketUtils() {
   symbolInfo = new CSymbolInfo;
   symbolInfo.Name(_Symbol);
   
   candlePatterns = new CCandlePattern;
   candlePatterns.MAPeriod(emaPeriod);
   if(!candlePatterns.Init(symbolInfo, candlePatternsTimeframe, 1.0)) { return false; }
   
   // Validate and initialize the indicator data sets
   if(!candlePatterns.ValidationSettings()) { return false; }
   // if(!candlePatterns.InitIndicators()){  return false;  }

   // FIXME: Old code, 
   emaIndicatorHandle = iMA(_Symbol, candlePatternsTimeframe, emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   if (emaIndicatorHandle == INVALID_HANDLE) {
      Alert("Error Creating Handle for EMA indicator - error: ", GetLastError(), "!!");
      return false;
   }
   
   // Ensure indexing of arrays is in timeseries format, i.e. 0 = current unfinished candle to n = oldest candle
   ArraySetAsSeries(symbolPriceData, true);
   ArraySetAsSeries(emaData, true);

   return true;
}

void deInitMarketUtils() {
   IndicatorRelease(emaIndicatorHandle);
   candlePatterns.DeInitHandler();
   delete candlePatterns;
}

bool handleMarketTickEvent() {
   if (!populateMarketData()) {
      return false;
   }
   
   if (!candlePatterns.OnTickHandler()) {
      return false;
   }
      
   checkMarketConditions();
   
   scanForBearishPriceActionPatterns();
   
   scanForBullishPriceActionPatterns();
   
   return true;
}

bool populateMarketData() {
   // Get the details of the latest x bars
   if (CopyRates(_Symbol, chartTimeframe, 0, 10, symbolPriceData) < 0) {
      PrintFormat("Error copying rates/history data - error: %d.", GetLastError());
      return false;
   }

   // Get the last price quote using the MQL5 MqlTick Structure
   if(!SymbolInfoTick(_Symbol, latestTickPrice)) {
      Alert("Error getting the latest price quote - error:", GetLastError(), ". ");
      return false;
   }
      
   if (emaIndicatorHandle == INVALID_HANDLE) {
      PrintFormat("Error copying Moving Average indicator buffer - Invalid handle");
      return false;
   }
   
   // Get the EMA data for the 
   if (CopyBuffer(emaIndicatorHandle, 0, 0, emaPeriod, emaData) < 0) {
      PrintFormat("Error copying Moving Average indicator buffer - error: %d.", GetLastError());
      return false;
   }
   
   return true;
}

void scanForBearishPriceActionPatterns() {
   // Scan back so patterns would've formed before time of detection/now
   int priceOffset = 1;
   
   // Price line at which to display the visual que
   double price = symbolPriceData[priceOffset].high;
   // double price = latestTickPrice.bid;

   // Time line at which to display the visual que
   datetime time = symbolPriceData[priceOffset].time;
   
   // int bearishPatternsScanned = 0;
   bearishPatternsFoundCounter = 0;
   
   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_THREE_BLACK_CROWS)) {
      highlightPriceActionPattern("3 Black Crows", time, price, clrRed);
      bearishPatternsFoundCounter++;
   }

   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_DARK_CLOUD_COVER)) {
      highlightPriceActionPattern("Dark Cloud Cover", time, price, clrRed);
      bearishPatternsFoundCounter++;
   }
      
   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_EVENING_DOJI)) {
      highlightPriceActionPattern("Evening Doji", time, price, clrRed);
      bearishPatternsFoundCounter++;
   }
   
   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_BEARISH_ENGULFING)) {
      highlightPriceActionPattern("Bearish Engulfing", time, price, clrRed);
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
   
   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_BEARISH_MEETING_LINES)) {
      highlightPriceActionPattern("Bearish Meeting Lines", time, price, clrRed);
      bearishPatternsFoundCounter++;
   }
}

void scanForBullishPriceActionPatterns() {
   // Scan back so patterns would've formed before time of detection/now
   int priceOffset = 1;
   
   // Price line at which to display the visual que
   double price = symbolPriceData[priceOffset].high;
   // double price = latestTickPrice.bid;

   // Time line at which to display the visual que
   datetime time = symbolPriceData[priceOffset].time;
   
   // int BullishPatternsScanned = 0;
   bullishPatternsFoundCounter = 0;
   
   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_THREE_WHITE_SOLDIERS)) {
      highlightPriceActionPattern("Morning Doji", time, price, clrBlue);
      bullishPatternsFoundCounter++;
   }
   
   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_PIERCING_LINE)) {
      highlightPriceActionPattern("Piercing Line", time, price, clrBlue);
      bullishPatternsFoundCounter++;
   }
   
   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_MORNING_DOJI)) {
      highlightPriceActionPattern("Morning Doji", time, price, clrBlue);
      bullishPatternsFoundCounter++;
   }

   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_BULLISH_ENGULFING)) {
      highlightPriceActionPattern("Bullish Engulfing", time, price, clrBlue);
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
   
   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_BULLISH_MEETING_LINES)) {
      highlightPriceActionPattern("Bullish Meeting Lines", time, price, clrBlue);
      bullishPatternsFoundCounter++;
   }
}

void highlightPriceActionPattern(string name, datetime time, double price, int colour) {
   // Add a visual cue
   string visualCueName = StringFormat("%s near %s and %f.", name, TimeToString(time), price);
   price = price + (50 * Point());
   
   if (ObjectCreate(0, visualCueName, OBJ_TEXT, 0, time, price)) {
      ObjectSetString(0, visualCueName, OBJPROP_TEXT, name);
      
      ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, colour);
      // ObjectSetString(0, visualCueName, OBJPROP_FONT, "Wingdings");
      ObjectSetInteger(0, visualCueName, OBJPROP_FONTSIZE, 10);
      ObjectSetDouble(0, visualCueName, OBJPROP_ANGLE, 90.0);      // rotation is clockwise if negative

      ObjectSetInteger(0, visualCueName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);      
      ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
      
      registerChartObject(visualCueName);
   } else {
      Print("Failed to highlight price action pattern on chart. Error: ", GetLastError());
   }
   
   PrintFormat("%s near %s and %f", name, TimeToString(time), price);
}

bool checkMarketConditions() {
   string marketConditionComment = StringFormat("Market trend is %s and %s.", isBearishMarket() ? "bearish" : "not bearish", isBullishMarket() ? "bullish" : "not bullish");
   Comment(marketConditionComment);
   
   return true;
}

void highlightMarketCondition(string visualCueName, ENUM_OBJECT objectType, double price, string conditionText, double angle, ENUM_ARROW_ANCHOR anchor, color objectColour) {
   // FIXME: Not a great UX.
   return;

   if (ObjectCreate(0, visualCueName, objectType, 0, TimeCurrent(), price)) {
      // ObjectSetString(0, visualCueName, OBJPROP_TEXT, conditionText);
      // ObjectSetInteger(0, visualCueName, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, visualCueName, OBJPROP_ARROWCODE, 252);//236
      ObjectSetInteger(0, visualCueName, OBJPROP_WIDTH, 3);
      ObjectSetDouble(0, visualCueName, OBJPROP_ANGLE, angle);          // Rotate <angle> degrees counter-clockwise
      ObjectSetInteger(0, visualCueName, OBJPROP_ANCHOR, anchor);
      ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, objectColour);
      ObjectSetInteger(0, visualCueName, OBJPROP_STYLE, STYLE_SOLID);         // set the border line style
      ObjectSetInteger(0, visualCueName, OBJPROP_BGCOLOR, clrWhite);
      ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, visualCueName, OBJPROP_BACK, true);
      ObjectSetInteger(0, visualCueName, OBJPROP_FILL, true);
      
      // Once the above actually flippen is working then test out setting the OBJPROP_YDISTANCE
      // ChartRedraw(0);
      
      registerChartObject(visualCueName);
   } else {
      Print("Failed to highlight market condition on chart. Error: ", GetLastError());
   }
}

bool isBearishMarket() {
   static bool bearishMarket = false;
   bool bearishMarketNow = false;

   if (symbolPriceData[1].open > symbolPriceData[1].close   // Previous candle was Bearish
         && latestTickPrice.bid < symbolPriceData[1].close  // Current price is lower than previous close
         && symbolPriceData[1].close  < emaData[0]) {       // Previous price is below EMA
      bearishMarket = true;
   }
   
   if (bearishMarketNow && !bearishMarket) {
      // Print("Market Condition changed: Not Bearish -> Bearish.");
      bearishMarket = true;
      
      string visualCueName = StringFormat("S4 signalled Bearish market at %s. \nBid price: %f. \nPrev. candle Close: %f. \nEMA: %f.", (string)TimeCurrent(), latestTickPrice.bid, symbolPriceData[1].close, emaData[0]);
      enableMarketPushNotifications ? SendNotification(visualCueName) : 0;
      // Add a visual cue
      highlightMarketCondition(visualCueName, OBJ_ARROW, symbolPriceData[1].high /*+ (visualObjectOffsetValue * Point())*/, "Open: Bearish", 90.0, ANCHOR_TOP, clrRed);
   }
   if (!bearishMarketNow && bearishMarket) {
      // Print("Market Condition changed: Bearish -> Not Bearish.");
      bearishMarket = false;
      
      string visualCueName = StringFormat("S4 signalled market no longer bearish at %s. \nAsk price: %f. \nPrev. candle Close: %f. \nEMA: %f.", (string)TimeCurrent(), latestTickPrice.ask, symbolPriceData[1].close, emaData[0]);
      enableMarketPushNotifications ? SendNotification(visualCueName) : 0; 
      // Add a visual cue
      highlightMarketCondition(visualCueName, OBJ_ARROW, symbolPriceData[1].low /*- (visualObjectOffsetValue * Point())*/, "Close: Bearish", 270.0, ANCHOR_TOP, clrBlack);
   }
   
   return bearishMarket;
}

bool isBullishMarket() {
   static bool bullishMarket = false;
   bool bullishMarketNow = false;
   
   if (symbolPriceData[1].open < symbolPriceData[1].close   // Previous candle was bullish
         && latestTickPrice.ask > symbolPriceData[1].close  // Current price is higher than previous close
         && symbolPriceData[1].close > emaData[0]) {       // Previous price is above EMA
      bullishMarketNow = true;
   }
   
   if (bullishMarketNow && !bullishMarket) {
      // Print("Market Condition changed: Not Bullish -> Bullish.");
      bullishMarket = true;
      
      string visualCueName = StringFormat("S4 signalled Bullish market at %s. \nAsk price: %f. \nPrev. candle Close: %f. \nEMA: %f.", (string)TimeCurrent(), latestTickPrice.ask, symbolPriceData[1].close, emaData[0]);
      enableMarketPushNotifications ? SendNotification(visualCueName) : 0;
      // Add a visual cue
      highlightMarketCondition(visualCueName, OBJ_ARROW, symbolPriceData[1].high /*+ (visualObjectOffsetValue * Point())*/, "Open: Bullish", 90.0, ANCHOR_TOP, clrBlue);
   }
   if (!bullishMarketNow && bullishMarket) {
      // Print("Market Condition changed: Bullish -> Not Bullish.");
      bullishMarket = false;
      
      string visualCueName = StringFormat("S4 signalled market no longer bullish at %s. \nAsk price: %f. \nPrev. candle Close: %f. \nEMA: %f.", (string)TimeCurrent(), latestTickPrice.ask, symbolPriceData[1].close, emaData[0]);
      enableMarketPushNotifications ? SendNotification(visualCueName) : 0;
      // Add a visual cue
      highlightMarketCondition(visualCueName, OBJ_ARROW, symbolPriceData[1].low /*- (visualObjectOffsetValue * Point())*/, "Close: Bullish", 270.0, ANCHOR_TOP, clrBlack);
   }
   
   return bullishMarket;
}