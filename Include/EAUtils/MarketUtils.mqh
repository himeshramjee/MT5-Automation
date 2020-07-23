#include <Expert/Expert.mqh>
#include <EAUtils/CandlePatterns.mqh>

// Market data
input bool              enablePushNotification = false;        // Enable market data push notifications

CExpert ExtExpert;
CCandlePattern *candlePatterns;

// EMA Indicator
input ENUM_TIMEFRAMES   emaTimeframe = PERIOD_M15;             // Chart timeframe to generate EMA data
input int               emaPeriod = 8;                         // EMA period

int                     emaIndicatorHandle = INVALID_HANDLE;
double                  emaData[];

// Market Price quotes
MqlRates symbolPriceData[];
MqlTick latestTickPrice;         // To be used for getting recent/latest price quotes

bool initMarketUtils() {
   if (!initExpert()) {
      return false;
   }

   emaIndicatorHandle = iMA(_Symbol, emaTimeframe, emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   if (emaIndicatorHandle == INVALID_HANDLE) {
      Alert("Error Creating Handle for EMA indicator - error: ", GetLastError(), "!!");
      return false;
   }
   
   // Ensure indexing of arrays is in timeseries format, i.e. 0 = current unfinished candle to n = oldest candle
   ArraySetAsSeries(symbolPriceData, true);
   ArraySetAsSeries(emaData, true);
   
   // symbolInfo = new CSymbolInfo;
   // symbolInfo.Name(_Symbol);
   
   return true;
}

void deInitMarketUtils() {
   IndicatorRelease(emaIndicatorHandle);
}

bool initExpert() {
   if(!ExtExpert.Init(_Symbol, chartTimeframe, EAEveryTick, EAMagic)) {
      printf(__FUNCTION__+": error initializing expert");   
      ExtExpert.Deinit();
      return false;
   }
   
   // Creating signal and register CandlePatterns as a signal filter
   CExpertSignal *signal = new CExpertSignal;
   if(signal==NULL){                printf(__FUNCTION__+": error creating signal"); ExtExpert.Deinit();   return false;  }
   ExtExpert.InitSignal(signal);
   candlePatterns = new CCandlePattern;
   if(candlePatterns==NULL){               printf(__FUNCTION__+": error creating filter0");  ExtExpert.Deinit();  return false;  }
   candlePatterns.MAPeriod(emaPeriod);   
   signal.AddFilter(candlePatterns);
   
   // Validate and initialize the indicator data sets
   if(!ExtExpert.ValidationSettings()) { printf(__FUNCTION__+": error validating expert settings"); ExtExpert.Deinit(); return false; }
   if(!ExtExpert.InitIndicators()){  printf(__FUNCTION__+": error initializing indicators"); ExtExpert.Deinit();  return false;  }
      
   return true;
}

bool handleMarketTickEvent() {
   ExtExpert.OnTick();
   
   if (!populateMarketData()) {
      return false;
   }
   
   checkMarketConditions();
   
   scanForPriceActionPatterns();
   
   return true;
}

bool populateMarketData() {
   // Get the details of the latest 3 bars
   if (CopyRates(_Symbol, chartTimeframe, 0, 3, symbolPriceData) < 0) {
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

void scanForPriceActionPatterns() {
   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_MORNING_DOJI)) {
      highlightPriceActionPattern("Morning Doji", latestTickPrice.ask);
   }

   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_THREE_BLACK_CROWS)) {
      highlightPriceActionPattern("3 Black Crows", latestTickPrice.ask);
   }

   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_DARK_CLOUD_COVER)) {
      highlightPriceActionPattern("Dark Cloud Cover", latestTickPrice.ask);
   }
   
   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_EVENING_DOJI)) {
      highlightPriceActionPattern("Evening Doji", latestTickPrice.ask);
   }

   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_BEARISH_ENGULFING)) {
      highlightPriceActionPattern("Bearish Engulfing", latestTickPrice.ask);
   }   

   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_BEARISH_HARAMI)) {
      highlightPriceActionPattern("Bearish Harami", latestTickPrice.ask);
   }
   
   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_EVENING_STAR)) {
      highlightPriceActionPattern("Evening Star", latestTickPrice.ask);
   }
   
   if (candlePatterns.CheckCandlestickPattern(ENUM_CANDLE_PATTERNS::CANDLE_PATTERN_BEARISH_MEETING_LINES)) {
      highlightPriceActionPattern("Bearish Meeting Lines", latestTickPrice.ask);
   }
}

void highlightPriceActionPattern(string name, double price) {
   datetime now = TimeCurrent();
   
   // Add a visual cue
   string visualCueName = name;
   ObjectCreate(0, visualCueName, OBJ_LABEL, 0, now, price);
   ObjectSetInteger(0, visualCueName, OBJPROP_ANCHOR, ANCHOR_TOP);      
   ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
   registerChartObject(visualCueName);
   
   PrintFormat("%s at time %s and price %f", name, TimeToString(now), latestTickPrice.ask);
}

bool checkMarketConditions() {
   string marketConditionComment = StringFormat("Market trend is %s and %s.", isMarketTrendingBearish() ? "bearish" : "not bearish", isMarketTrendingBullish() ? "bullish" : "not bullish");
   Comment(marketConditionComment);
   
   return true;
}

bool isMarketTrendingBearish() {
   static bool bearishMarket = false;
   bool bearishMarketNow = candlePatterns.CheckPatternAllBearish();
   
   if (bearishMarketNow && !bearishMarket) {
      // Print("Market Condition changed: Not Bearish -> Bearish.");
      bearishMarket = true;
      
      string visualCueName = StringFormat("S4 signalled Bearish market at %s. \nBid price: %f. \nPrev. candle Close: %f. \nEMA: %f.", (string)TimeCurrent(), latestTickPrice.bid, symbolPriceData[1].close, emaData[0]);
      SendNotification(visualCueName);
      
      // Add a visual cue
      ObjectCreate(0, visualCueName, OBJ_VLINE, 0, TimeCurrent(), symbolPriceData[1].close);
      ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
      ObjectSetInteger(0, visualCueName, OBJPROP_BACK, true);
      registerChartObject(visualCueName);
   }
   if (!bearishMarketNow && bearishMarket) {
      // Print("Market Condition changed: Bearish -> Not Bearish.");
      bearishMarket = false;
      
      string visualCueName = StringFormat("S4 signalled market no longer bearish at %s. \nAsk price: %f. \nPrev. candle Close: %f. \nEMA: %f.", (string)TimeCurrent(), latestTickPrice.ask, symbolPriceData[1].close, emaData[0]);
      SendNotification(visualCueName);
      
      // Add a visual cue
      ObjectCreate(0, visualCueName, OBJ_VLINE, 0, TimeCurrent(), symbolPriceData[1].close);
      ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
      ObjectSetInteger(0, visualCueName, OBJPROP_BACK, true);
      registerChartObject(visualCueName);
   }
   
   return bearishMarket;
}


bool isMarketTrendingBullish() {
   static bool bullishMarket = false;
   bool bullishMarketNow = candlePatterns.CheckPatternAllBullish();
   
   if (bullishMarketNow && !bullishMarket) {
      // Print("Market Condition changed: Not Bullish -> Bullish.");
      bullishMarket = true;
   }
   if (!bullishMarketNow && bullishMarket) {
      // Print("Market Condition changed: Bullish -> Not Bullish.");
      bullishMarket = false;
   }
   
   return bullishMarket;
}

// TODO: Refactor and update this to signal up, down or ranging market
bool trendIsDown() {
   static bool trendIsDown = false;
   bool confirmation1 = true;

   if (symbolPriceData[1].high > emaData[0]) {
      confirmation1 = false;
   }

   if (confirmation1) {
      if (!trendIsDown && enablePushNotification) {
         
         string visualCueName = StringFormat("S4 signalled Bearish market at %s. \nBid price: %f. \nPrev. candle High: %f. \nEMA: %f.", (string)TimeCurrent(), latestTickPrice.bid, symbolPriceData[1].high, emaData[0]);
         SendNotification(visualCueName);
         
         // Add a visual cue
         ObjectCreate(0, visualCueName, OBJ_VLINE, 0, TimeCurrent(), symbolPriceData[1].high);
         ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
         ObjectSetInteger(0, visualCueName, OBJPROP_BACK, true);
         registerChartObject(visualCueName);
      }
      
      // Set these after the notification goes out
      trendIsDown = true;
   } else {
      if (trendIsDown && enablePushNotification) {
         
         string visualCueName = StringFormat("S4 signalled NOT Bearish market at %s. \nBid price: %f. \nPrev. candle High: %f. \nEMA: %f.", (string)TimeCurrent(), latestTickPrice.bid, symbolPriceData[1].high, emaData[0]);
         SendNotification(visualCueName);
         
         // Add a visual cue
         ObjectCreate(0, visualCueName, OBJ_VLINE, 0, TimeCurrent(), symbolPriceData[1].high);
         ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
         ObjectSetInteger(0, visualCueName, OBJPROP_BACK, true);
         registerChartObject(visualCueName);
      }
      
      // Set these after the notification goes out
      trendIsDown = false;
   }
      
   return confirmation1;
}