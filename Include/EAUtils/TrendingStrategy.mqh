//--- input parameters
input group "S1: Strategy 1 - ADX, MA Trends"
input int s1ADXPeriod = 8;       // ADX Period
input double s1AdxMin = 22.0;    // Minimum ADX Value
// TODO: https://www.mql5.com/en/forum/109552/page4#comment_3049209
input double s1TakeProfit = 100000;  // Profit (points)

ENUM_TIMEFRAMES s1ChartTimeframe = PERIOD_M15;

//--- Price parameters
int s1ADXHandle; // handle for our ADX indicator
double plsDI[],minDI[],adxVal[]; // Dynamic arrays to hold the values of +DI, -DI and ADX values for each bars

bool initTrendingIndicators() {

   //--- Get handle for ADX indicator
   // NULL and 0 are the Symbol and Timeframe values respectively and values returned are from the currently active chart
   s1ADXHandle = iADX(NULL, s1ChartTimeframe, s1ADXPeriod);
      
   //--- What if handle returns Invalid Handle
   if(s1ADXHandle < 0) {
      Alert("Error Creating Handles for indicators - error: ", GetLastError(), "!!");
      // return(INIT_FAILED);
      return false;
   }
   
   /*
     Let's make sure our arrays values for the Rates, ADX Values and MA values 
     is store serially similar to the timeseries array
   */
   // the rates arrays
   // the ADX DI+values array
   ArraySetAsSeries(plsDI,true);
   // the ADX DI-values array
   ArraySetAsSeries(minDI,true);
   // the ADX values arrays
   ArraySetAsSeries(adxVal,true);

   return true;
}

void releaseTrendingIndicators() {
   // Release indicator handles
   IndicatorRelease(s1ADXHandle);
}

bool populateTrendingPrices() {
   
   //--- Copy the new values of our indicators to buffers (arrays) using the handle
   if(CopyBuffer(s1ADXHandle, 0, 0, PRICE_CLOSE, adxVal) < 0 
      || CopyBuffer(s1ADXHandle, 1, 0, PRICE_CLOSE, plsDI) < 0
      || CopyBuffer(s1ADXHandle, 2, 0, PRICE_CLOSE, minDI) < 0) {
      PrintFormat("Error copying ADX indicator Buffers - error: %d.", GetLastError());
      return false;
   }
   
   return true;
}

bool runTrendingBuyStrategy() {
   /*
      Check for a long/Buy Setup : 
         MA-8 increasing upwards, 
         Previous price close above it, 
         ADX > 22, 
         +DI > -DI
   */
   // Declare bool type variables to hold our Buy Conditions
   bool Buy_Condition_1 = (candlePatterns.MA(0) > candlePatterns.MA(1)) && (candlePatterns.MA(1) > candlePatterns.MA(2));  // MA-8 Increasing upwards
   bool Buy_Condition_2 = (symbolPriceData[1].close > candlePatterns.MA(1));         // previuos price closed above MA-8
   bool Buy_Condition_3 = (adxVal[0] > s1AdxMin);                          // Current ADX value greater than minimum value (22)
   bool Buy_Condition_4 = (plsDI[0] > minDI[0]);                           // +DI greater than -DI

   // Print(StringFormat("Buy conditions: 1 = %s, 2 = %s, 3 = %s, 4 = %s", Buy_Condition_1 ? "True" : "False", Buy_Condition_2 ? "True" : "False", Buy_Condition_3 ? "True" : "False", Buy_Condition_4 ? "True" : "False"));

   if(Buy_Condition_1 && Buy_Condition_2) {
      if(Buy_Condition_3 && Buy_Condition_4) {         
         setupGenericTradeRequest();
         mTradeRequest.price = NormalizeDouble(latestTickPrice.ask, _Digits);            // latest ask price
         mTradeRequest.tp = latestTickPrice.ask + s1TakeProfit * _Point; // Take Profit
         mTradeRequest.type = ORDER_TYPE_BUY;                                         // Buy Order
         mTradeRequest.comment = mTradeRequest.comment + "S1 Buy conditions.";
         
         return true;
      }
   }
   
   return false;
}

bool runTrendingSellStrategy() {
   /*
      Check for a Short/Sell Setup : 
         MA-8 decreasing downwards, 
         Previous price close below it, 
         ADX > 22, 
         -DI > +DI
   */
   // Declare bool type variables to hold our Sell Conditions
   bool Sell_Condition_1 = (candlePatterns.MA(0) < candlePatterns.MA(1)) && (candlePatterns.MA(1) < candlePatterns.MA(2));    // MA-8 decreasing downwards
   bool Sell_Condition_2 = (symbolPriceData[1].close < candlePatterns.MA(1));           // Previous price closed below MA-8
   bool Sell_Condition_3 = (adxVal[0] > s1AdxMin);                            // Current ADX value greater than minimum (22)
   bool Sell_Condition_4 = (plsDI[0] < minDI[0]);                             // -DI greater than +DI
   
   if(Sell_Condition_1 && Sell_Condition_2) {
      if(Sell_Condition_3 && Sell_Condition_4) {         
         setupGenericTradeRequest();
         mTradeRequest.price = NormalizeDouble(latestTickPrice.bid, _Digits);           // latest Bid price
         mTradeRequest.tp = latestTickPrice.bid - s1TakeProfit * _Point; // Take Profit
         mTradeRequest.type = ORDER_TYPE_SELL;                                         // Sell Order
         mTradeRequest.comment = mTradeRequest.comment + "S1 Sell conditions.";
         
         return true;
      }
   }
   
   return false;
}

bool runTrendingStrategy() {
   if (openPositionLimitReached()){
      return false;
   }
 
   if (!populateTrendingPrices()) {
      return false;
   }
   
   if (runTrendingBuyStrategy()) {
      return true;
   }
   
   if (runTrendingSellStrategy()) {
      return true;
   }

   return false;
}