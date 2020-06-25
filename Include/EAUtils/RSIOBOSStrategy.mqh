//+------------------------------------------------------------------+
//|                                                  RSIStrategy.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

input group "S2: Strategy 2 - RSI OB/OS"
input int      S2RSIWorkingPeriod = 8;             // RSI Number of bars for to look back at
input bool     s2BoomMode = true;                  // Trade Boom if true, trade crash if false
input double   s2RSISignalLevel = 78.0;            // RSI level to trigger new order signal
input double   s2RSITakeProfitLevel = 30.0;        // RSI level for Take Profit
input int      s2RSIPositionOpenDelayMinutes = 0;  // Number of minutes to wait before opening a new position
input bool     s2ConfirmSpotPrice = false;         // Open new position after confirming spot price

double rsiVal[];
int rsiHandle;

bool initRSIOBOSIndicators() {
   //--- Get handle for RSI indicator
   // NULL and 0 are the Symbol and Timeframe values respectively and values returned are from the currently active chart
   rsiHandle = iRSI(NULL, 0, S2RSIWorkingPeriod, PRICE_CLOSE);
   
   //--- What if handle returns Invalid Handle
   if(rsiHandle < 0) {
      Alert("Error Creating Handles for indicators - error: ", GetLastError());
      return false;
   }
   
   /*
     Let's make sure our arrays values for the RSI values 
     are store serially similar to the timeseries array
   */
   ArraySetAsSeries(rsiVal, true);

   return true;
}

void releaseRSIOBOSIndicators() {
   // Release indicator handles
   IndicatorRelease(rsiHandle);
}


void populateRSIOBOSPrices() {
   //--- Copy the new values of our indicators to buffers (arrays) using the handle
   if(CopyBuffer(rsiHandle, 0, 0, PRICE_CLOSE, rsiVal) < 0) {
      Alert("Error copying RSI OBOS indicator Buffers - error:", GetLastError(), ". ");
      return;
   }
}

/*
   Check for a Short/Sell Setup : 
      Trend?
      RSI > y%
*/
void runRSIOBOSSellStrategy() {
   static bool s2SellCondition1SignalOn;
   static datetime s2SellCondition1TimeAtSignal;
   static double s2SellConditionPriceAtSignal;
   
   if (!s2SellCondition1SignalOn && rsiVal[0] >= s2RSISignalLevel) {
      s2SellCondition1SignalOn = true;
      s2SellCondition1TimeAtSignal = TimeCurrent();
      s2SellConditionPriceAtSignal = latestTickPrice.bid;
      
      // Add a visual cue
      ObjectCreate(0, (string)s2SellCondition1TimeAtSignal, OBJ_ARROW_SELL, 0, TimeCurrent(), latestTickPrice.bid);
      ObjectSetInteger(0, (string)s2SellCondition1TimeAtSignal, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
      ObjectSetInteger(0, (string)s2SellCondition1TimeAtSignal, OBJPROP_COLOR, clrRed);
      
      // Signal triggered, now wait x mins before opening the Sell position      
      return; 
   }
   
   if(s2SellCondition1SignalOn) {
      int minutesPassed = (int) ((TimeCurrent() - s2SellCondition1TimeAtSignal) / 60);
      if (minutesPassed < s2RSIPositionOpenDelayMinutes) {
         // wait bit longer
         return;
      }
      
      if (s2ConfirmSpotPrice && (s2SellConditionPriceAtSignal < latestTickPrice.bid)) {
         // Reset signal as all conditions have triggered, no order can be placed
         s2SellCondition1SignalOn = false;
         return;
      }
            
      setupGenericTradeRequest();
      mTradeRequest.type = ORDER_TYPE_SELL;                                         // Sell Order
      mTradeRequest.price = NormalizeDouble(latestTickPrice.bid, _Digits);           // latest Bid price
      mTradeRequest.comment = mTradeRequest.comment + "S2 Sell conditions.";
      doPlaceOrder = true;
      
      // Reset signal as all conditions have triggered and order can be placed
      s2SellCondition1SignalOn = false;
   }
}


/*
   Check for a Long/Buy Setup : 
      Trend?
      RSI < y%
*/
void runRSIOBOSBuyStrategy() {
   static bool s2BuyCondition1SignalOn;
   static datetime s2BuyCondition1TimeAtSignal;
   static double s2BuyConditionPriceAtSignal;
   
   if (!s2BuyCondition1SignalOn && rsiVal[0] <= s2RSISignalLevel) {
      s2BuyCondition1SignalOn = true;
      s2BuyCondition1TimeAtSignal = TimeCurrent();
      s2BuyConditionPriceAtSignal = latestTickPrice.bid;
      
      // Add a visual cue
      ObjectCreate(0, (string)s2BuyCondition1TimeAtSignal, OBJ_ARROW_BUY, 0, TimeCurrent(), latestTickPrice.bid);
      ObjectSetInteger(0, (string)s2BuyCondition1TimeAtSignal, OBJPROP_ANCHOR, ANCHOR_TOP);
      ObjectSetInteger(0, (string)s2BuyCondition1TimeAtSignal, OBJPROP_COLOR, clrBlue);
      
      // Signal triggered, now wait x mins before opening the Buy position
      return; 
   }
   
   if(s2BuyCondition1SignalOn) {
      int minutesPassed = (int) ((TimeCurrent() - s2BuyCondition1TimeAtSignal) / 60);
      if (minutesPassed < s2RSIPositionOpenDelayMinutes) {
         // wait bit longer
         return;
      }
      
      if (s2ConfirmSpotPrice && (s2BuyConditionPriceAtSignal < latestTickPrice.bid)) {
         // Reset signal as all conditions have triggered, no order can be placed
         s2BuyCondition1SignalOn = false;
         return;
      }
      
      setupGenericTradeRequest();
      mTradeRequest.type = ORDER_TYPE_BUY;
      mTradeRequest.price = NormalizeDouble(latestTickPrice.bid, _Digits);
      mTradeRequest.comment = mTradeRequest.comment + "S2 Buy conditions.";
      doPlaceOrder = true;
      
      // Reset signal as all conditions have triggered and order can be placed
      s2BuyCondition1SignalOn = false;
   }
}

void closeITMPositions() {
   int openPositionCount = PositionsTotal(); // number of open positions
   
   for (int i = 0; i < openPositionCount; i++) {
      ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);

      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetSymbol(i);
      double profitLoss = PositionGetDouble(POSITION_PROFIT);
      ulong  magic = PositionGetInteger(POSITION_MAGIC);
      double volume = PositionGetDouble(POSITION_VOLUME);
      
      // Only act on positions opened by this EA
      if (magic == EAMagic) {
         if (positionType == POSITION_TYPE_SELL) {
            if(profitLoss > 0 && rsiVal[0] <= s2RSITakeProfitLevel) {
               PrintFormat("Closing profit Sell position - %s, Ticket: %d. Symbol: %s. Profit/Loss: %f. RSI: %f.", EnumToString(positionType), ticket, symbol, profitLoss, rsiVal[0]);
               
               closePosition(magic, ticket, symbol, positionType, volume, "S2 profit conditions.");
            }
         }
         if (positionType == POSITION_TYPE_BUY) {
            if(profitLoss > 0 && rsiVal[0] >= s2RSITakeProfitLevel) {
               PrintFormat("Closing profit Buy position - %s, Ticket: %d. Symbol: %s. Profit/Loss: %f. RSI: %f.", EnumToString(positionType), ticket, symbol, profitLoss, rsiVal[0]);
               
               closePosition(magic, ticket, symbol, positionType, volume, "S2 profit conditions.");
            }
         }
      }
   }
}

void runRSIOBOSStrategy() {
   doPlaceOrder = false;
   
   populateRSIOBOSPrices();

   closeITMPositions();
      
   if (openPositionLimitReached()){
      return;
   }

   if (s2BoomMode) {
      runRSIOBOSSellStrategy();
   } else {
      runRSIOBOSBuyStrategy();
   }

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