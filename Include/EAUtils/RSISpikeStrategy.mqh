//+------------------------------------------------------------------+
//|                                             RSISpikeStrategy.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

input group "S3: Strategy 3"
input double   rsiSellDeltaCondition = 40.0;   // RSI delta value to trigger a Sell position
input int      rsiSellPositionOpenMinutes = 4; // Number of minutes to wait before opening a Sell position
input int      rsiSellTakeProfitMinutes = 4;   // Number of minutes to wait before closing position
input int      rsiSpikeWorkingPeriod = 8;      // Number of bars to look back at

double   rsiSpikeValues[];
int      rsiSpikeHandle;
double   rsiSpikePreviousValue = 0.0;
double   rsiSpikeCurrentValue = 0.0;
double   rsiSpikePreviousPrice = 0.0;
double   rsiSpikeCurrentPrice = 0.0;

double   closePrices[];
bool     sellCondition1SignalOn = false;
datetime sellCondition1TimeAtSignal;
int      barsSinceSignalOn = 0;

bool initRSISpikeIndicators() {
   rsiSpikeHandle = iRSI(NULL, 0, rsiSpikeWorkingPeriod, PRICE_CLOSE);
   
   //--- What if handle returns Invalid Handle
   if(rsiSpikeHandle < 0) {
      Alert("Error Creating Handles for indicators - error: ", GetLastError(), "!!");
      return false;
   }
   
   /*
     Let's make sure our arrays values for the RSI values 
     are store serially similar to the timeseries array
   */
   ArraySetAsSeries(rsiVal, true);
   ArraySetAsSeries(closePrices, true);

   return true;
}

void releaseRSISpikeIndicators() {
   // Release indicator handles
   IndicatorRelease(rsiSpikeHandle);
}


void populateRSIOBOSData() {
   // Get the last price quote using the MQL5 MqlTick Structure
   if(!SymbolInfoTick(_Symbol, latestTickPrice)) {
      Alert("Error getting the latest price quote - error:", GetLastError(), ". ");
      return;
   }
   
   // Copy old RSI indicator value
   rsiSpikePreviousValue = rsiSpikeCurrentValue;
  
   // Get the current value of the indicator
   if(CopyBuffer(rsiSpikeHandle, 0, 0, PRICE_CLOSE, rsiSpikeValues) < 0) {
      Alert("Error copying RSI Spike indicator Buffers - error: ", GetLastError(), ". ");
      return;
   }
   
   // Set new RSI indicator value
   rsiSpikeCurrentValue = rsiSpikeValues[0];
}

/*
   Check for a Short/Sell Setup : 
      RSI delta is > x%
*/
void runRSISpikeSellStrategy() {
   // Has the RSI indicator change meet the first condition?
   if (!sellCondition1SignalOn && (rsiSpikeCurrentValue - rsiSpikePreviousValue) > rsiSellDeltaCondition) {
      sellCondition1SignalOn = true;
      sellCondition1TimeAtSignal = TimeCurrent();
      
      // Add a visual cue
      bool signalVisualCueAdded = ObjectCreate(0, string(sellCondition1TimeAtSignal), OBJ_ARROW_THUMB_UP, 0, TimeCurrent(), latestTickPrice.bid);
      if (signalVisualCueAdded) {
         ObjectSetInteger(0, (string)sellCondition1TimeAtSignal, OBJPROP_ANCHOR, ANCHOR_TOP);
         ObjectSetInteger(0, (string)sellCondition1TimeAtSignal, OBJPROP_COLOR, clrRed);
         Print("Added visual cue for object at Time = ", (string)sellCondition1TimeAtSignal, " and bid price = ", latestTickPrice.bid);
      } else {
         Print("Failed to add visual cue for object at Time = ", sellCondition1TimeAtSignal, " and bid price = ", latestTickPrice.bid, ". (Error = ", GetLastError(), ").");
      }
      
      // Signal triggered, now wait x mins before opening the Sell position      
      return; 
   }
   
   if (sellCondition1SignalOn) {
      // Check if a new Sell position should be opened now
      int minutesPassed = (int) ((TimeCurrent() - sellCondition1TimeAtSignal) / 60);
      if (minutesPassed >= rsiSellPositionOpenMinutes) {
         // Open new Sell position
         setupGenericTradeRequest();
         mTradeRequest.type = ORDER_TYPE_SELL;                                         // Sell Order
         mTradeRequest.price = NormalizeDouble(latestTickPrice.bid, _Digits);           // latest Bid price
         if (SetStopLoss) {
            mTradeRequest.sl = mTradeRequest.price + stopLoss * _Point; // Stop Loss
         }
         if (SetTakeProfit) {
            mTradeRequest.tp = mTradeRequest.price - takeProfit * _Point; // Take Profit
         }
         
         doPlaceOrder = true;
         
         sellCondition1SignalOn = false;  
      }
   }
}

void closeSpikeSellPositions() {
   int openPositionCount = PositionsTotal(); // number of open positions
   
   if (openPositionCount > 0) {
  
      for (int i = 0; i < openPositionCount; i++) {
         ulong  magic = PositionGetInteger(POSITION_MAGIC);
         ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
         
         if (magic == EAMagic) { 
            if (positionType == POSITION_TYPE_SELL) {               
               ulong ticket = PositionGetTicket(i);
               string symbol = PositionGetSymbol(i);
               double profitLoss = PositionGetDouble(POSITION_PROFIT);
               double volume = PositionGetDouble(POSITION_VOLUME);
               datetime openTime = (datetime) PositionGetInteger(POSITION_TIME);
               datetime currentTime = TimeCurrent();
               int minutesPassed = (int) ((currentTime - openTime) / 60);
               
               if (profitLoss > 0 && minutesPassed >= rsiSellTakeProfitMinutes) {
                  PrintFormat("Closing Sell position - %s, Ticket: %d. Symbol: %s. Profit/Loss: %f. RSI: %f.", EnumToString(positionType), ticket, symbol, profitLoss, rsiSpikeCurrentValue);
                  closePosition(magic, ticket, symbol, positionType, volume);
               }
            }
         }
      }
   }
}

void runRSISpikesStrategy() {
   doPlaceOrder = false;
   
   populateRSIOBOSData();

   // Close positions (after x delay)
   closeSpikeSellPositions();

   for (int i = 0; i < openPositionsLimit - PositionsTotal(); i++) {
      runRSISpikeSellStrategy();
         
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
      if (!accountHasSufficientMargin(_Symbol, lot, mTradeRequest.type)) {
         Print("Insufficient funds in account. Disable this EA until you sort that out.");
         return;
      }
   
      // Place the order
      sendOrder();
   }
}