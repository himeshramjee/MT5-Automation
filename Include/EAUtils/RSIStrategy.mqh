//+------------------------------------------------------------------+
//|                                                  RSIStrategy.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

input double rsiSellLevel = 85.0; // RSI level to trigger Sell order
input double rsiSellTakeProfitLevel = 30.0; // RSI Level for Sell TP
// input double rsiBuyLevel = 15.0; // RSI level to trigger Buy order
// double rsiBuyLevel = 15.0; // RSI level to trigger Buy order

double rsiVal[];
int rsiHandle;
bool doPlaceOrder = false;

bool initRSIIndicators() {
   //--- Get handle for RSI indicator
   // NULL and 0 are the Symbol and Timeframe values respectively and values returned are from the currently active chart
   rsiHandle = iRSI(NULL, 0, 8, PRICE_CLOSE);
   
   //--- What if handle returns Invalid Handle
   if(rsiHandle < 0) {
      Alert("Error Creating Handles for indicators - error: ", GetLastError(), "!!");
      // return(INIT_FAILED);
      return false;
   }
   
   /*
     Let's make sure our arrays values for the RSI values 
     are store serially similar to the timeseries array
   */
   ArraySetAsSeries(rsiVal, true);

   return true;
}

void releaseRSIIndicators() {
   // Release indicator handles
   IndicatorRelease(rsiHandle);
}


void populateRSIPrices() {
   // Get the last price quote using the MQL5 MqlTick Structure
   if(!SymbolInfoTick(_Symbol, latestTickPrice)) {
      Alert("Error getting the latest price quote - error:", GetLastError(), ". ");
      return;
   }
     
   //--- Copy the new values of our indicators to buffers (arrays) using the handle
   if(CopyBuffer(rsiHandle, 0, 0, PRICE_CLOSE, rsiVal) < 0) {
      Alert("Error copying RSI indicator Buffers - error:", GetLastError(), ". ");
      return;
   }
}

/*
   Check for a Long/Buy Setup : 
      Trend?
      RSI < x%
*/
/*
void runRSIBuyStrategy() {

   // Declare bool type variables to hold our Buy Conditions
   bool Buy_Condition_1 = rsiVal[0] < rsiBuyLevel; // RSI < x%
   
   // PrintFormat("Checking Buy condition - rsIVal = %f. rsiBuyLevel = %f", rsiVal[0], rsiBuyLevel);
   
   if(Buy_Condition_1) {
      // Do we have enough cash to place an order?
      validateFreeMargin(_Symbol, Lot, ORDER_TYPE_BUY);
      
      mTradeRequest.type = ORDER_TYPE_BUY;                                         // Buy Order  
      mTradeRequest.price = NormalizeDouble(latestTickPrice.ask, _Digits);            // latest ask price
      if (SetStopLoss) {
         mTradeRequest.sl = mTradeRequest.price - stopLoss * _Point ; // Stop Loss
      }
      if (SetTakeProfit) {
         mTradeRequest.tp = mTradeRequest.price + takeProfit * _Point; // Take Profit
      }
      
      doPlaceOrder = true;
   }
}
*/

/*
   Check for a Short/Sell Setup : 
      Trend?
      RSI > y%
*/
void runRSISellStrategy() {
   // Declare bool type variables to hold our Sell Conditions
   bool Sell_Condition_1 = rsiVal[0] >= rsiSellLevel;    // RSI > y%
   
   if(Sell_Condition_1) {
      // Do we have enough cash to place an order?
      validateFreeMargin(_Symbol, Lot, ORDER_TYPE_SELL);
      
      mTradeRequest.type = ORDER_TYPE_SELL;                                         // Sell Order
      mTradeRequest.price = NormalizeDouble(latestTickPrice.bid, _Digits);           // latest Bid price
      if (SetStopLoss) {
         mTradeRequest.sl = mTradeRequest.price + stopLoss * _Point; // Stop Loss
      }
      if (SetTakeProfit) {
         mTradeRequest.tp = mTradeRequest.price - takeProfit * _Point; // Take Profit
      }
      
      doPlaceOrder = true;
   }
}

void closeSellOrders() {
   int openPositionCount = PositionsTotal(); // number of open positions
   
   for (int i = 0; i < openPositionCount; i++) {
      ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
      if (positionType != POSITION_TYPE_SELL) {
         continue;
      }
      
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetSymbol(i);
      double profitLoss = PositionGetDouble(POSITION_PROFIT);
      ulong  magic = PositionGetInteger(POSITION_MAGIC);
      double volume = PositionGetDouble(POSITION_VOLUME);
      
      if(rsiVal[0] <= rsiSellTakeProfitLevel) {
         PrintFormat("Closing profit position - %s, Ticket: %d. Symbol: %s. Profit/Loss: %f. RSI: %f.", EnumToString(positionType), ticket, symbol, profitLoss, rsiVal[0]);
         closePosition(magic, ticket, symbol, positionType, volume);
      }
   }
}

void runRSIStrategy() {
   doPlaceOrder = false;
   
   populateRSIPrices();

   // Now we can place either a Buy or Sell order
   setupGenericTradeRequest();
   
   // runRSIBuyStrategy();
   
   closeSellOrders();
      
   if (openPositionLimitReached()){
      return;
   }
  
   runRSISellStrategy();

   if (!doPlaceOrder) {
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