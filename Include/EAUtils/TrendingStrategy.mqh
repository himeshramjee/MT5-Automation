//+------------------------------------------------------------------+
//|                                             TrendingStrategy.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

//--- input parameters
input int ADXPeriod = 8;   // ADX Period
input int MAPeriod = 8;    // Moving Average Period
input double AdxMin = 22.0;   // Minimum ADX Value

//--- Price parameters
int adxHandle; // handle for our ADX indicator
int maHandle;  // handle for our Moving Average indicator
double plsDI[],minDI[],adxVal[]; // Dynamic arrays to hold the values of +DI, -DI and ADX values for each bars
double maVal[]; // Dynamic array to hold the values of Moving Average for each bars

bool initTrendingIndicators() {

   //--- Get handle for ADX indicator
   // NULL and 0 are the Symbol and Timeframe values respectively and values returned are from the currently active chart
   adxHandle = iADX(NULL, 0, ADXPeriod);
   
   //--- Get the handle for Moving Average indicator
   // _Symbol, symbol() or NULL return the Chart Symbol for the currently active chart
   // _Period, period() or 0 return the Timeframe for the currently active chart
   maHandle = iMA(_Symbol,_Period, MAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   //--- What if handle returns Invalid Handle
   if(adxHandle < 0 || maHandle < 0) {
      Alert("Error Creating Handles for indicators - error: ", GetLastError(), "!!");
      // return(INIT_FAILED);
      return false;
   }
   
   /*
     Let's make sure our arrays values for the Rates, ADX Values and MA values 
     is store serially similar to the timeseries array
   */
   // the rates arrays
   ArraySetAsSeries(mBarPriceInfo,true);
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
   IndicatorRelease(adxHandle);
   IndicatorRelease(maHandle);
}

void populateTrendingPrices() {
   // Get the last price quote using the MQL5 MqlTick Structure
   if(!SymbolInfoTick(_Symbol, latestTickPrice)) {
      // TODO: Post to Journal
      Alert("Error getting the latest price quote - error:", GetLastError(), ". ");
      return;
   }
   
   // Get the details of the latest 3 bars
   if(CopyRates(_Symbol,_Period, 0, 3, mBarPriceInfo) < 0) {
      // TODO: Post to Journal
      Alert("Error copying rates/history data - error:", GetLastError(), ". ");
      return;
   }
   
   //--- Copy the new values of our indicators to buffers (arrays) using the handle
   if(CopyBuffer(adxHandle, 0, 0, PRICE_CLOSE, adxVal) < 0 
      || CopyBuffer(adxHandle, 1, 0, PRICE_CLOSE, plsDI) < 0
      || CopyBuffer(adxHandle, 2, 0, PRICE_CLOSE, minDI) < 0) {
      // TODO: Post to Journal
      Alert("Error copying ADX indicator Buffers - error:",GetLastError(),"!!");
      return;
   }
     
   if(CopyBuffer(maHandle, 0, 0, 3, maVal) < 0) {
      // TODO: Post to Journal
      Alert("Error copying Moving Average indicator buffer - error:",GetLastError());
      return;
   }
   
   // FIXME: Why index 1?
   priceClose = mBarPriceInfo[1].close;
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
   bool Buy_Condition_2 = (priceClose > maVal[1]);                         // previuos price closed above MA-8
   bool Buy_Condition_3 = (adxVal[0] > AdxMin);                           // Current ADX value greater than minimum value (22)
   bool Buy_Condition_4 = (plsDI[0] > minDI[0]);                           // +DI greater than -DI

   // Print(StringFormat("Buy conditions: 1 = %s, 2 = %s, 3 = %s, 4 = %s", Buy_Condition_1 ? "True" : "False", Buy_Condition_2 ? "True" : "False", Buy_Condition_3 ? "True" : "False", Buy_Condition_4 ? "True" : "False"));

   if(Buy_Condition_1 && Buy_Condition_2) {
      if(Buy_Condition_3 && Buy_Condition_4) {
         // Do we have enough cash to place an order?
         validateFreeMargin(_Symbol, Lot, ORDER_TYPE_BUY);
         
         mTradeRequest.price = NormalizeDouble(latestTickPrice.ask, _Digits);            // latest ask price
         if (SetStopLoss) {
            mTradeRequest.sl = latestTickPrice.ask - stopLoss * _Point ; // Stop Loss
         }
         mTradeRequest.tp = latestTickPrice.ask + takeProfit * _Point; // Take Profit
         mTradeRequest.type = ORDER_TYPE_BUY;                                         // Buy Order
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
   bool Sell_Condition_2 = (priceClose < maVal[1]);                              // Previous price closed below MA-8
   bool Sell_Condition_3 = (adxVal[0] > AdxMin);                             // Current ADX value greater than minimum (22)
   bool Sell_Condition_4 = (plsDI[0] < minDI[0]);                             // -DI greater than +DI
   
   if(Sell_Condition_1 && Sell_Condition_2) {
      if(Sell_Condition_3 && Sell_Condition_4) {
         // Do we have enough cash to place an order?
         validateFreeMargin(_Symbol, Lot, ORDER_TYPE_SELL);
         
         mTradeRequest.price = NormalizeDouble(latestTickPrice.bid, _Digits);           // latest Bid price
         if (SetStopLoss) {
            mTradeRequest.sl = latestTickPrice.bid + stopLoss * _Point; // Stop Loss
         }
         mTradeRequest.tp = latestTickPrice.bid - takeProfit * _Point; // Take Profit
         mTradeRequest.type = ORDER_TYPE_SELL;                                         // Sell Order
      }
   }
}

void runTrendingStrategy() {
 
   populateTrendingPrices();

   // Now we can place either a Buy or Sell order
   setupGenericTradeRequest();
   
   runTrendingBuyStrategy();
   
   runTrendingSellStrategy();

   if (mTradeRequest.type == NULL) {
      // Print("Neither Buy nor Sell order conditions were met. No position will be opened.");
      return;
   }
   
   // Validate SL and TP
   // TODO: Clean up method names
   if (!CheckStopLossAndTakeprofit(mTradeRequest.type, latestTickPrice.bid, mTradeRequest.sl, mTradeRequest.tp)
      || !CheckStopLossAndTakeprofit(mTradeRequest.type, latestTickPrice.ask, mTradeRequest.sl, mTradeRequest.tp)) {
      return;
   }

   // Do we have enough cash to place an order?
   if (!validateFreeMargin(_Symbol, Lot, mTradeRequest.type)) {
      Print("Insufficient funds in account. Disable this EA until you sort that out.");
      return;
   }

   // Place the order
   sendOrder();
}