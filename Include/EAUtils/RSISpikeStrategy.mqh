input group "S3: Strategy 3 - RSI Spike Delta"
input double            s3RSISpikeDeltaValue = 5.0;        // RSI level delta to trigger new order signal
input double            s3MinimumTakeProfit = 23.0;         // RSI level for Take Profit
input int               s3RSIPositionOpenDelayMinutes = 0;  // Number of minutes to wait before opening a new position
input int               s3RSIPositionCloseDelayMinutes = 0; // Number of minutes to wait before closing a new position
input bool              s3EnablePushNotification = false;   // Enable signal push notifications

ENUM_TIMEFRAMES s3ChartTimeframe = PERIOD_M1;

// RSI Indicator
int      s3RSIIndicatorHandle;
double   s3RSIData[];
int      s3RSIDataPointsToLookBackOn = 8;    // RSI Number of bars for to look back at
double   s3RSIPreviousValue = 0.0;
double   s3RSICurrentValue = 0.0;

bool     s3ConfirmSpotPrice = false;          // Open new position after confirming spot price

bool initRSISpikeIndicators() {
   //--- Get handle for RSI indicator
   // NULL and 0 are the Symbol and Timeframe values respectively and values returned are from the currently active chart
   s3RSIIndicatorHandle = iRSI(NULL, s3ChartTimeframe, s3RSIDataPointsToLookBackOn, PRICE_CLOSE);
   
   //--- What if handle returns Invalid Handle
   if(s3RSIIndicatorHandle < 0) {
      Alert("Error Creating Handle for RSI 8 indicators - error: ", GetLastError());
      return false;
   }
   // Ensure indexing of arrays is in timeseries format, i.e. 0 = current unfinished candle to n = oldest candle
   ArraySetAsSeries(s3RSIData, true);

   return true;
}

void releaseRSISpikeIndicators() {
   // Release indicator handles
   IndicatorRelease(s3RSIIndicatorHandle);
}


bool populateS3Prices() {
   // Copy old RSI indicator value
   s3RSIPreviousValue = s3RSICurrentValue;
   
   //--- Copy the new values of our indicators to buffers (arrays) using the handle
   if(CopyBuffer(s3RSIIndicatorHandle, 0, 0, PRICE_CLOSE, s3RSIData) < 0) {
      Alert("Error copying RSI OBOS indicator Buffers - error:", GetLastError(), ". ");
      return false;
   }
   
   // Set new RSI indicator value
   s3RSICurrentValue = s3RSIData[0];
   
   return true;
}

/*
   Check for a Short/Sell Setup : 
      Trend?
      RSI > y%
*/
bool runS3RSISellStrategy() {
   static bool s3SellCondition1SignalOn;
   static datetime s3SellCondition1TimeAtSignal;
   static double s3SellConditionPriceAtSignal;
   
   if (!isBearishMarket()) {
      return false;
   }
   
   if (!s3SellCondition1SignalOn && ((s3RSICurrentValue - s3RSIPreviousValue) >= s3RSISpikeDeltaValue)) {
      s3SellCondition1SignalOn = true;
      s3SellCondition1TimeAtSignal = TimeCurrent();
      s3SellConditionPriceAtSignal = latestTickPrice.bid;
      
      // Add a visual cue
      string visualCueName = StringFormat("S3 RSI signalled at %s. Bid price: %f.", (string)s3SellCondition1TimeAtSignal, latestTickPrice.bid);
      ObjectCreate(0, visualCueName, OBJ_ARROW_DOWN, 0, TimeCurrent(), latestTickPrice.bid);
      ObjectSetInteger(0, visualCueName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
      ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
      registerChartObject(visualCueName);
      
      // Signal triggered, now wait x mins before opening the Sell position      
      return false; 
   }
   
   if(s3SellCondition1SignalOn) {
      int minutesPassed = (int) ((TimeCurrent() - s3SellCondition1TimeAtSignal) / 60);
      if (minutesPassed < s3RSIPositionOpenDelayMinutes) {
         // wait bit longer
         return false;
      }
      
      if (s3ConfirmSpotPrice && (s3SellConditionPriceAtSignal < latestTickPrice.bid)) {
         // Reset signal as all conditions have triggered, no order can be placed
         s3SellCondition1SignalOn = false;
         return false;
      }
            
      setupGenericTradeRequest();
      mTradeRequest.type = ORDER_TYPE_SELL;                                         // Sell Order
      mTradeRequest.price = NormalizeDouble(latestTickPrice.bid, _Digits);           // latest Bid price
      mTradeRequest.comment = mTradeRequest.comment + "S3 Sell conditions.";
      
      // Reset signal as all conditions have triggered and order can be placed
      s3SellCondition1SignalOn = false;
      
      return true;
   }
   
   return false;
}

/*
   Check for a Short/Sell Setup : 
      Trend?
      RSI > y%
*/
bool runS3RSIBuyStrategy() {
   static bool s3BuyCondition1SignalOn;
   static datetime s3BuyCondition1TimeAtSignal;
   static double s3BuyConditionPriceAtSignal;
   
   if (!isBullishMarket()) {
      return false;
   }
      
   if (!s3BuyCondition1SignalOn && (s3RSICurrentValue <= s3RSISpikeDeltaValue)) {
      s3BuyCondition1SignalOn = true;
      s3BuyCondition1TimeAtSignal = TimeCurrent();
      s3BuyConditionPriceAtSignal = latestTickPrice.ask;
      
      // Add a visual cue
      string visualCueName = StringFormat("S3 RSI signalled at %s. Ask price: %f.", (string)s3BuyCondition1TimeAtSignal, latestTickPrice.ask);
      ObjectCreate(0, visualCueName, OBJ_ARROW_UP, 0, TimeCurrent(), latestTickPrice.ask);
      ObjectSetInteger(0, visualCueName, OBJPROP_ANCHOR, ANCHOR_TOP);
      ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
      registerChartObject(visualCueName);
      
      // Signal triggered, now wait x mins before opening the Sell position      
      return false;
   }
   
   if(s3BuyCondition1SignalOn) {
      int minutesPassed = (int) ((TimeCurrent() - s3BuyCondition1TimeAtSignal) / 60);
      if (minutesPassed < s3RSIPositionOpenDelayMinutes) {
         // wait bit longer
         return false;
      }
      
      if (s3ConfirmSpotPrice && (s3BuyConditionPriceAtSignal < latestTickPrice.ask)) {
         // Reset signal as all conditions have triggered, no order can be placed
         s3BuyCondition1SignalOn = false;
         return false;
      }
            
      setupGenericTradeRequest();
      mTradeRequest.type = ORDER_TYPE_BUY;
      mTradeRequest.price = NormalizeDouble(latestTickPrice.ask, _Digits);
      mTradeRequest.comment = mTradeRequest.comment + "S3 Buy conditions.";
      
      // Reset signal as all conditions have triggered and order can be placed
      s3BuyCondition1SignalOn = false;
      
      return true;
   }
   
   return false;
}

void closeS3Positions() {
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
         datetime openTime = (datetime) PositionGetInteger(POSITION_TIME);
         datetime currentTime = TimeCurrent();
         int minutesPassed = (int) ((currentTime - openTime) / 60);
         
         if (profitLoss >= s3MinimumTakeProfit) {
            PrintFormat("Close profitable position - %s, Ticket: %d. Symbol: %s. Profit/Loss: %f. RSI: %f.", EnumToString(positionType), ticket, symbol, profitLoss, s3RSIData[0]);
            
            closePosition(magic, ticket, symbol, (positionType == POSITION_TYPE_SELL ? POSITION_TYPE_SELL : POSITION_TYPE_BUY), volume, "S3 profit conditions.", true);
         } else {
            // PrintFormat("Not profitable - P/L: %f. Min. passed: %d. RSI val: %f > %f.", profitLoss, minutesPassed, s3RSIData[0], s3MinimumTakeProfit);
            // wait a bit longer
            return;
         }
      }
   }
}

bool runRSISpikeStrategy() {
   if (!populateS3Prices()) {
      return false;
   }

   closeS3Positions();
      
   if (openPositionLimitReached()){
      return false;
   }

   // return runS3RSISellStrategy();
   return runS3RSIBuyStrategy();
}