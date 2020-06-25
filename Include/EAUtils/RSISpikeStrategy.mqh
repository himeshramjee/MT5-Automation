//+------------------------------------------------------------------+
//|                                             RSISpikeStrategy.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

input group "S3: Strategy 3 - RSI Spike Delta"
input int      s3RSIWorkingPeriod = 8;      // Number of bars for RSI to look back at
input double   s3RSILevelDeltaForSell = 40.0;   // RSI delta value to trigger a Sell position
input bool     s3DelaySellPositionOpening = true; // Delay the opening of Sell positions
input int      s3RSISellPositionOpenMinutes = 0; // Number of minutes to wait before opening a Sell position
input int      s3RSISellTakeProfitMinutes = 4;   // Number of minutes to wait before closing a Sell position

double   s3RSIValues[];
int      s3RSIHandle;
double   s3RSIPreviousValue = 0.0;
double   s3RSICurrentValue = 0.0;

bool initRSISpikeIndicators() {
   s3RSIHandle = iRSI(NULL, chartTimeFrame, s3RSIWorkingPeriod, PRICE_CLOSE);
   
   //--- What if handle returns Invalid Handle
   if(s3RSIHandle < 0) {
      Alert("Error Creating Handles for indicators - error: ", GetLastError(), "!!");
      return false;
   }
   
   /*
     Let's make sure our arrays values for the RSI values 
     are store serially similar to the timeseries array
   */
   ArraySetAsSeries(rsiVal, true);

   return true;
}

void releaseRSISpikeIndicators() {
   // Release indicator handles
   IndicatorRelease(s3RSIHandle);
}


void populateRSIOBOSData() {
   // Copy old RSI indicator value
   s3RSIPreviousValue = s3RSICurrentValue;
  
   // Get the current value of the indicator
   if(CopyBuffer(s3RSIHandle, 0, 0, PRICE_CLOSE, s3RSIValues) < 0) {
      Alert("Error copying RSI Spike indicator Buffers - error: ", GetLastError(), ". ");
      return;
   }
   
   // Set new RSI indicator value
   s3RSICurrentValue = s3RSIValues[0];
}

/*
   Check for a Short/Sell Setup : 
      RSI delta is > x%
*/
void runRSISpikeSellStrategy() {
   static bool s3SellCondition1SignalOn;
   static datetime s3SellCondition1TimeAtSignal;
   
   // Has the RSI indicator change meet the first condition?
   if (!s3SellCondition1SignalOn && (s3RSICurrentValue - s3RSIPreviousValue) > s3RSILevelDeltaForSell) {
      s3SellCondition1SignalOn = true;
      s3SellCondition1TimeAtSignal = TimeCurrent();
      
      // Add a visual cue
      ObjectCreate(0, (string)s3SellCondition1TimeAtSignal, OBJ_ARROW_SELL, 0, TimeCurrent(), latestTickPrice.bid);
      ObjectSetInteger(0, (string)s3SellCondition1TimeAtSignal, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
      ObjectSetInteger(0, (string)s3SellCondition1TimeAtSignal, OBJPROP_COLOR, clrRed);
      
      // Signal triggered, now wait x mins before opening the Sell position      
      return; 
   }
   
   if (s3SellCondition1SignalOn) {
      // Check if a new Sell position should be opened now
      int minutesPassed = (int) ((TimeCurrent() - s3SellCondition1TimeAtSignal) / 60);
      if (s3DelaySellPositionOpening && minutesPassed < s3RSISellPositionOpenMinutes) {
         // Wait bit longer
         return;
      }
      
      // Open new Sell position
      setupGenericTradeRequest();
      mTradeRequest.type = ORDER_TYPE_SELL;                                         // Sell Order
      mTradeRequest.price = NormalizeDouble(latestTickPrice.bid, _Digits);           // latest Bid price
      mTradeRequest.comment = mTradeRequest.comment + "S3 Sell conditions.";
      doPlaceOrder = true;
      
      // Reset signal as all conditions have triggered   
      s3SellCondition1SignalOn = false;  
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
               
               if (profitLoss > 0 && minutesPassed >= s3RSISellTakeProfitMinutes) {
                  PrintFormat("Closing Sell position - %s, Ticket: %d. Symbol: %s. Profit/Loss: %f. RSI: %f.", EnumToString(positionType), ticket, symbol, profitLoss, s3RSICurrentValue);
                  closePosition(magic, ticket, symbol, positionType, volume, "S3 profit conditions.");
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
         
      // Do we have enough cash to place an order?
      if (!accountHasSufficientMargin(_Symbol, lot, mTradeRequest.type)) {
         Print("Insufficient funds in account. Disable this EA until you sort that out.");
         return;
      }
   
      // Place the order
      sendOrder();
   }
}