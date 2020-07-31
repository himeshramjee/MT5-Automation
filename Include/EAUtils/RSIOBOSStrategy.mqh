input group "S2: Strategy 2 - RSI OB/OS"
input double            s2RSISignalLevel = 78.0;            // RSI % change to trigger new order signal
input double            s2RSITakeProfitLevel = 30.0;        // RSI % level for Take Profit
input bool              s2EnablePushNotification = false;   // Enable signal push notifications
input double            s2MinimumTakeProfit = 23.0;          // Minimum required TP in currency

ENUM_TIMEFRAMES s2ChartTimeframe = PERIOD_M1;
ENUM_TIMEFRAMES s2EMATimeframe = PERIOD_M1;

// RSI Indicator
int      s2RSIIndicatorHandle;
double   s2RSIData[];
int      s2RSIDataPointsToLookBackOn = 8;    // RSI Number of bars for to look back at
double   s2RSIPreviousValue = 0.0;
double   s2RSICurrentValue = 0.0;

bool     s2ConfirmSpotPrice = true;          // Open new position after confirming spot price

bool initRSIOBOSIndicators() {
   //--- Get handle for RSI indicator
   // NULL and 0 are the Symbol and Timeframe values respectively and values returned are from the currently active chart
   s2RSIIndicatorHandle = iRSI(NULL, s2ChartTimeframe, s2RSIDataPointsToLookBackOn, PRICE_CLOSE);
   
   //--- What if handle returns Invalid Handle
   if(s2RSIIndicatorHandle < 0) {
      Alert("Error Creating Handle for RSI indicator - error: ", GetLastError());
      return false;
   }
   
   // Ensure indexing of arrays is in timeseries format, i.e. 0 = current unfinished candle to n = oldest candle
   ArraySetAsSeries(s2RSIData, true);

   return true;
}

void releaseRSIOBOSIndicators() {
   // Release indicator handles
   IndicatorRelease(s2RSIIndicatorHandle);
}


bool populateRSIOBOSPrices() {
   // Copy old RSI indicator value
   s2RSIPreviousValue = s2RSICurrentValue;
   
   //--- Copy the new values of our indicators to buffers (arrays) using the handle
   if(CopyBuffer(s2RSIIndicatorHandle, 0, 0, PRICE_CLOSE, s2RSIData) < 0) {
      Alert("Error copying RSI OBOS indicator Buffers - error:", GetLastError(), ". ");
      return false;
   }
   
   // Set new RSI indicator value
   s2RSICurrentValue = s2RSIData[0];
   
   return true;
}

/*
   Check for a Short/Sell Setup : 
      Trend?
      RSI > y%
*/
bool runRSIOBOSSellStrategy() {
   static bool s2SellCondition1SignalOn;
   static datetime s2SellCondition1TimeAtSignal;
   static double s2SellConditionPriceAtSignal;
   
   /*
   if (!trendIsDown()) {
      return false;
   }
   */
   
   if (!s2SellCondition1SignalOn && s2EnablePushNotification && s2RSIData[0] >= 78) {
      SendNotification("S2 RSI Signal is above 78 for Symbol: " + Symbol() + ". RSI: " + (string)s2RSIData[0]);
   }
   
   if (!s2SellCondition1SignalOn && s2RSIData[0] >= s2RSISignalLevel) {
      // Print("S2 RSI Signal is active for Symbol: " + Symbol() + ". RSI: " + (string)s2RSIData[0]);
      s2SellCondition1SignalOn = true;
      s2SellCondition1TimeAtSignal = TimeCurrent();
      s2SellConditionPriceAtSignal = latestTickPrice.bid;
      
      // Add a visual cue
      string visualCueName = StringFormat("S2 RSI signalled at %s. Bid price: %f.", (string)s2SellCondition1TimeAtSignal, latestTickPrice.bid);
      ObjectCreate(0, visualCueName, OBJ_ARROW_DOWN, 0, TimeCurrent(), latestTickPrice.bid);
      ObjectSetInteger(0, visualCueName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
      ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
      registerChartObject(visualCueName);
      
      // Signal triggered, now wait x mins before opening the Sell position      
      return false;
   }
   
   if(s2SellCondition1SignalOn) {      
      if (s2ConfirmSpotPrice && (s2SellConditionPriceAtSignal < latestTickPrice.bid)) {
         // PrintFormat("S2 RSI Signal was active but bid price is now higher than at signal time. Sell position will not be opened. Signal at %f is < current bid of %f. Resetting signal flag to false.", s2SellConditionPriceAtSignal, latestTickPrice.bid);
         // Reset signal as all conditions have triggered, no order can be placed
         s2SellCondition1SignalOn = false;
         return false;
      }
            
      setupGenericTradeRequest();
      mTradeRequest.type = ORDER_TYPE_SELL;                                         // Sell Order
      mTradeRequest.price = NormalizeDouble(latestTickPrice.bid, _Digits);           // latest Bid price
      mTradeRequest.comment = mTradeRequest.comment + "S2 Sell conditions.";
      
      // Reset signal as all conditions have triggered and order can be placed
      s2SellCondition1SignalOn = false;
      
      return true;
   }
   
   return false;
}

void closeITMPositions() {
   int openPositionCount = PositionsTotal(); // number of open positions
   
   for (int i = 0; i < openPositionCount; i++) {
      ulong ticket = PositionGetTicket(i);
      ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);

      string symbol = PositionGetSymbol(i);
      double profitLoss = PositionGetDouble(POSITION_PROFIT);
      ulong  magic = PositionGetInteger(POSITION_MAGIC);
      double volume = PositionGetDouble(POSITION_VOLUME);
      
      // Only act on positions opened by this EA
      if (magic == EAMagic) {
         if (positionType == POSITION_TYPE_SELL) {
            if(profitLoss >= s2MinimumTakeProfit || (profitLoss >= s2MinimumTakeProfit && s2RSIData[0] <= s2RSITakeProfitLevel)) {
               PrintFormat("Close profitable position - %s, Ticket: %d. Symbol: %s. Profit/Loss: %f. RSI: %f.", EnumToString(positionType), ticket, symbol, profitLoss, s2RSIData[0]);
               
               closePosition(magic, ticket, symbol, positionType, volume, "S2 profit conditions.", true);
            } else {
               // wait bit longer
               return;
            }
         }
      }
   }
}

bool runRSIOBOSStrategy() {
   if (!populateRSIOBOSPrices()) {
      return false;
   }

   closeITMPositions();
      
   if (newOrdersPermitted()){
      return false;
   }

   return runRSIOBOSSellStrategy();
}