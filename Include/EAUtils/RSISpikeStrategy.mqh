input group "S3: Strategy 3 - RSI Spike Delta"
input double            s3RSISpikeDeltaValue = 40.0;        // RSI % change to trigger new order signal
input double            s3RSITakeProfitLevel = 30.0;         // RSI % level for Take Profit
input int               s3RSIPositionOpenDelayMinutes = 0;  // Number of minutes to wait before opening a new position
input int               s3RSIPositionCloseDelayMinutes = 5; // Number of minutes to wait before closing a new position
input ENUM_TIMEFRAMES   s3EMATimeframe = PERIOD_M1;         // Chart timeframe to generate EMA data
input bool              s3EnablePushNotification = false;   // Enable signal push notifications

// RSI Indicator
int      s3RSIIndicatorHandle;
double   s3RSIData[];
int      s3RSIDataPointsToLookBackOn = 8;    // RSI Number of bars for to look back at
double   s3RSIPreviousValue = 0.0;
double   s3RSICurrentValue = 0.0;

// EMA Indicator
int      s3EMAIndicatorHandle; 
double   s3EMAData[];
int      s3EMADataPointsToLookBackOn = 5;                    // Number of past bars used to generate EMA data
int      s3DataCountToConfirmDownTrend = 3;  // Number of EMA data points used to confirm downtrend

// Price quotes
MqlRates s3SymbolPriceData[];
bool     s3ConfirmSpotPrice = true;          // Open new position after confirming spot price

bool initRSISpikeIndicators() {
   //--- Get handle for RSI indicator
   // NULL and 0 are the Symbol and Timeframe values respectively and values returned are from the currently active chart
   s3RSIIndicatorHandle = iRSI(NULL, chartTimeframe, s3RSIDataPointsToLookBackOn, PRICE_CLOSE);
   
   //--- What if handle returns Invalid Handle
   if(s3RSIIndicatorHandle < 0) {
      Alert("Error Creating Handle for RSI 8 indicators - error: ", GetLastError());
      return false;
   }
   
   s3EMAIndicatorHandle = iMA(_Symbol, s3EMATimeframe, s3EMADataPointsToLookBackOn, 0, MODE_EMA, PRICE_CLOSE);
   
   if (s3EMAIndicatorHandle < 0) {
      Alert("Error Creating Handle for EMA 8 indicators - error: ", GetLastError(), "!!");
      return false;
   }
   
   // Ensure indexing of arrays is in timeseries format, i.e. 0 = current unfinished candle to n = oldest candle
   ArraySetAsSeries(s3RSIData, true);
   ArraySetAsSeries(s3SymbolPriceData, true);
   ArraySetAsSeries(s3EMAData, true);

   return true;
}

void releaseRSISpikeIndicators() {
   // Release indicator handles
   IndicatorRelease(s3RSIIndicatorHandle);
   IndicatorRelease(s3EMAIndicatorHandle);
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

   // Get the details of the latest 3 bars
   if(CopyRates(_Symbol, chartTimeframe, 0, 3, s3SymbolPriceData) < 0) {
      Alert("Error copying rates/history data - error:", GetLastError(), ". ");
      return false;
   }
   
   // Get the EMA data for the 
   if(CopyBuffer(s3EMAIndicatorHandle, 0, 0, s3DataCountToConfirmDownTrend, s3EMAData) < 0) {
      Alert("Error copying Moving Average indicator buffer - error:",GetLastError());
      return false;
   }
   
   return true;
}

bool isS3DownTrendConfirmed() {
   static bool trendIsDown = false;
   bool confirmation1 = true;
        
   if (s3SymbolPriceData[1].high > s3EMAData[0]) {
      confirmation1 = false;
   }
      
   if (confirmation1) {
      Comment("S3: EMA signalling market is in downtrend.");
      
      if (!trendIsDown && s3EnablePushNotification) {
         // SendNotification("S3 EMA Signal. Trend is down. Symbol: " + Symbol());
         // Add a visual cue
         string visualCueName = StringFormat("S3 RSI signalled Bearish at %s. \nBid price: %f. \nPrev. candle High: %f. \nEMA: %f.", (string)TimeCurrent(), latestTickPrice.bid, s3SymbolPriceData[1].high, s3EMAData[0]);
         ObjectCreate(0, visualCueName, OBJ_VLINE, 0, TimeCurrent(), s3SymbolPriceData[1].high);
         ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
         registerChartObject(visualCueName);
      }
      
      // Set these after the notification goes out
      trendIsDown = true;
      // Print("S3: EMA signalling market is in downtrend. Flag is now ", (trendIsDown ? "True" : "False"));
   } else {
      Comment("S3: EMA signalling market is NOT in downtrend.");
      
      if (trendIsDown && s3EnablePushNotification) {
         // SendNotification("S3 EMA Signal. Trend is no longer down. Symbol: " + Symbol());
         // Add a visual cue
         string visualCueName = StringFormat("S3 RSI signalled NOT bearish at %s. \nBid price: %f. \nPrev. candle High: %f. \nEMA: %f.", (string)TimeCurrent(), latestTickPrice.bid, s3SymbolPriceData[1].high, s3EMAData[0]);
         ObjectCreate(0, visualCueName, OBJ_VLINE, 0, TimeCurrent(), s3SymbolPriceData[1].high);
         ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, clrBlue);
         ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
         registerChartObject(visualCueName);
      }
      
      // Set these after the notification goes out
      trendIsDown = false;
      // Print("S3: EMA signalling market is NOT in downtrend. Flag is now: " + (trendIsDown ? "True" : "False"));
   }
      
   return confirmation1;
}

/*
   Check for a Short/Sell Setup : 
      Trend?
      RSI > y%
*/
void runS3RSISellStrategy() {
   static bool s3SellCondition1SignalOn;
   static datetime s3SellCondition1TimeAtSignal;
   static double s3SellConditionPriceAtSignal;
   
   if (!isS3DownTrendConfirmed()) {
      return;
   }
   
   // if (!s3SellCondition1SignalOn && (s3RSICurrentValue - s3RSIPreviousValue) >= s3RSISpikeDeltaValue) {
   if (!s3SellCondition1SignalOn && (s3RSICurrentValue < s3RSIPreviousValue)) {
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
      return; 
   }
   
   if(s3SellCondition1SignalOn) {
      int minutesPassed = (int) ((TimeCurrent() - s3SellCondition1TimeAtSignal) / 60);
      if (minutesPassed < s3RSIPositionOpenDelayMinutes) {
         // wait bit longer
         return;
      }
      
      if (s3ConfirmSpotPrice && (s3SellConditionPriceAtSignal < latestTickPrice.bid)) {
         // Reset signal as all conditions have triggered, no order can be placed
         s3SellCondition1SignalOn = false;
         return;
      }
            
      setupGenericTradeRequest();
      mTradeRequest.type = ORDER_TYPE_SELL;                                         // Sell Order
      mTradeRequest.price = NormalizeDouble(latestTickPrice.bid, _Digits);           // latest Bid price
      mTradeRequest.comment = mTradeRequest.comment + "S3 Sell conditions.";
      doPlaceOrder = true;
      
      // Reset signal as all conditions have triggered and order can be placed
      s3SellCondition1SignalOn = false;
   }
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
         if (positionType == POSITION_TYPE_SELL) {
            datetime openTime = (datetime) PositionGetInteger(POSITION_TIME);
            datetime currentTime = TimeCurrent();
            int minutesPassed = (int) ((currentTime - openTime) / 60);
            
            if (profitLoss > 0 && minutesPassed > s3RSIPositionCloseDelayMinutes) { // && s3RSIData[0] <= s3RSITakeProfitLevel) {
               PrintFormat("Close profitable position - %s, Ticket: %d. Symbol: %s. Profit/Loss: %f. RSI: %f.", EnumToString(positionType), ticket, symbol, profitLoss, s3RSIData[0]);
               
               closePosition(magic, ticket, symbol, positionType, volume, "S3 profit conditions.", true);
            } else {
               // PrintFormat("Not profitable - P/L: %f. Min. passed: %d. RSI val: %f > %f.", profitLoss, minutesPassed, s3RSIData[0], s3RSITakeProfitLevel);
               // wait a bit longer
               return;
            }
         }
      }
   }
}

void runRSISpikeStrategy() {
   doPlaceOrder = false;
   
   if (!populateS3Prices()) {
      return;
   }

   closeS3Positions();
      
   if (openPositionLimitReached()){
      return;
   }

   runS3RSISellStrategy();

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