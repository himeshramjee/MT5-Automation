//+------------------------------------------------------------------+
//|                                             TrendingStrategy.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

//--- input parameters
input group "S1: Strategy 1 - ADX, MA Trends"
input int s1ADXPeriod = 8;       // ADX Period
input int s1MAPeriod = 8;        // Moving Average Period
input double s1AdxMin = 22.0;    // Minimum ADX Value
input double s1TakeProfit = 100000;  // Profit (pips)

//--- Price parameters
int s1ADXHandle; // handle for our ADX indicator
int s1MAHandle;  // handle for our Moving Average indicator
double plsDI[],minDI[],adxVal[]; // Dynamic arrays to hold the values of +DI, -DI and ADX values for each bars
double maVal[]; // Dynamic array to hold the values of Moving Average for each bars
MqlRates symbolPriceValues[];

bool initTrendingIndicators() {

   //--- Get handle for ADX indicator
   // NULL and 0 are the Symbol and Timeframe values respectively and values returned are from the currently active chart
   s1ADXHandle = iADX(NULL, chartTimeFrame, s1ADXPeriod);
   
   //--- Get the handle for Moving Average indicator
   // _Symbol, symbol() or NULL return the Chart Symbol for the currently active chart
   // chartTimeFrame, period() or 0 return the Timeframe for the currently active chart
   s1MAHandle = iMA(_Symbol, chartTimeFrame, s1MAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   //--- What if handle returns Invalid Handle
   if(s1ADXHandle < 0 || s1MAHandle < 0) {
      Alert("Error Creating Handles for indicators - error: ", GetLastError(), "!!");
      // return(INIT_FAILED);
      return false;
   }
   
   /*
     Let's make sure our arrays values for the Rates, ADX Values and MA values 
     is store serially similar to the timeseries array
   */
   // the rates arrays
   ArraySetAsSeries(symbolPriceValues,true);
   // the ADX DI+values array
   ArraySetAsSeries(plsDI,true);
   // the ADX DI-values array
   ArraySetAsSeries(minDI,true);
   // the ADX values arrays
   ArraySetAsSeries(adxVal,true);
   // the MA-8 values arrays
   ArraySetAsSeries(maVal,true);

   return true;
}

void releaseTrendingIndicators() {
   // Release indicator handles
   IndicatorRelease(s1ADXHandle);
   IndicatorRelease(s1MAHandle);
}

void populateTrendingPrices() {
   // Get the details of the latest 3 bars
   if(CopyRates(_Symbol, chartTimeFrame, 0, 3, symbolPriceValues) < 0) {
      // TODO: Post to Journal
      Alert("Error copying rates/history data - error:", GetLastError(), ". ");
      return;
   }
   
   //--- Copy the new values of our indicators to buffers (arrays) using the handle
   if(CopyBuffer(s1ADXHandle, 0, 0, PRICE_CLOSE, adxVal) < 0 
      || CopyBuffer(s1ADXHandle, 1, 0, PRICE_CLOSE, plsDI) < 0
      || CopyBuffer(s1ADXHandle, 2, 0, PRICE_CLOSE, minDI) < 0) {
      // TODO: Post to Journal
      Alert("Error copying ADX indicator Buffers - error:",GetLastError(),"!!");
      return;
   }
     
   if(CopyBuffer(s1MAHandle, 0, 0, 3, maVal) < 0) {
      // TODO: Post to Journal
      Alert("Error copying Moving Average indicator buffer - error:",GetLastError());
      return;
   }
}

void runTrendingBuyStrategy() {
   /*
      Check for a long/Buy Setup : 
         MA-8 increasing upwards, 
         Previous price close above it, 
         ADX > 22, 
         +DI > -DI
   */
   // Declare bool type variables to hold our Buy Conditions
   bool Buy_Condition_1 = (maVal[0] > maVal[1]) && (maVal[1] > maVal[2]);  // MA-8 Increasing upwards
   bool Buy_Condition_2 = (symbolPriceValues[1].close > maVal[1]);         // previuos price closed above MA-8
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
         
         doPlaceOrder = true;
      }
   }
}

void runTrendingSellStrategy() {
   /*
      Check for a Short/Sell Setup : 
         MA-8 decreasing downwards, 
         Previous price close below it, 
         ADX > 22, 
         -DI > +DI
   */
   // Declare bool type variables to hold our Sell Conditions
   bool Sell_Condition_1 = (maVal[0] < maVal[1]) && (maVal[1] < maVal[2]);    // MA-8 decreasing downwards
   bool Sell_Condition_2 = (symbolPriceValues[1].close < maVal[1]);           // Previous price closed below MA-8
   bool Sell_Condition_3 = (adxVal[0] > s1AdxMin);                            // Current ADX value greater than minimum (22)
   bool Sell_Condition_4 = (plsDI[0] < minDI[0]);                             // -DI greater than +DI
   
   if(Sell_Condition_1 && Sell_Condition_2) {
      if(Sell_Condition_3 && Sell_Condition_4) {         
         setupGenericTradeRequest();
         mTradeRequest.price = NormalizeDouble(latestTickPrice.bid, _Digits);           // latest Bid price
         mTradeRequest.tp = latestTickPrice.bid - s1TakeProfit * _Point; // Take Profit
         mTradeRequest.type = ORDER_TYPE_SELL;                                         // Sell Order
         mTradeRequest.comment = mTradeRequest.comment + "S1 Sell conditions.";
         
         doPlaceOrder = true;
      }
   }
}

void runTrendingStrategy() {
   doPlaceOrder = false;

   if (openPositionLimitReached()){
      return;
   }
 
   populateTrendingPrices();
   
   runTrendingBuyStrategy();
   
   runTrendingSellStrategy();

   if (!doPlaceOrder) {
      // Print("Neither Buy nor Sell order conditions were met. No position will be opened.");
      return;
   }
   
   // Do we have enough cash to place an order?
   if (!accountHasSufficientMargin(_Symbol, lot, mTradeRequest.type)) {
      Print("Insufficient funds in account. Disable this EA until you sort that out.");
      return;
   }

   // Place the order
   sendOrder();
}