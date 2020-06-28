input group "S2: Strategy 2 - RSI OB/OS"
input double            s2RSISignalLevel = 78.0;            // RSI % change to trigger new order signal
input double            s2RSITakeProfitLevel = 30.0;        // RSI % level for Take Profit
input ENUM_TIMEFRAMES   s2EMATimeframe = PERIOD_M1;         // Chart timeframe to generate EMA data
input bool              s2EnablePushNotification = false;   // Enable signal push notifications
input double            s2MinimumTakeProfit = 0.0;          // Minimum required TP in currency

// RSI Indicator
int      s2RSIIndicatorHandle;
double   s2RSIData[];
int      s2RSIDataPointsToLookBackOn = 8;    // RSI Number of bars for to look back at
double   s2RSIPreviousValue = 0.0;
double   s2RSICurrentValue = 0.0;

// EMA Indicator
int      s2EMAIndicatorHandle; 
double   s2EMAData[];
int      s2EMAPeriod = 8;                    // Number of past bars used to generate EMA data
int      s2EMADataPointsToConfirmDownTrend = 3;

bool     s2ConfirmSpotPrice = true;          // Open new position after confirming spot price

// Price quotes
MqlRates s2SymbolPriceData[];

bool initRSIOBOSIndicators() {
   //--- Get handle for RSI indicator
   // NULL and 0 are the Symbol and Timeframe values respectively and values returned are from the currently active chart
   s2RSIIndicatorHandle = iRSI(NULL, chartTimeframe, s2RSIDataPointsToLookBackOn, PRICE_CLOSE);
   
   //--- What if handle returns Invalid Handle
   if(s2RSIIndicatorHandle < 0) {
      Alert("Error Creating Handle for RSI indicator - error: ", GetLastError());
      return false;
   }
   
   s2EMAIndicatorHandle = iMA(_Symbol, s2EMATimeframe, s2EMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   if (s2EMAIndicatorHandle < 0) {
      Alert("Error Creating Handle for EMA indicator - error: ", GetLastError(), "!!");
      return false;
   }
   
   // Ensure indexing of arrays is in timeseries format, i.e. 0 = current unfinished candle to n = oldest candle
   ArraySetAsSeries(s2RSIData, true);
   ArraySetAsSeries(s2SymbolPriceData, true);
   ArraySetAsSeries(s2EMAData, true);

   return true;
}

void releaseRSIOBOSIndicators() {
   // Release indicator handles
   IndicatorRelease(s2RSIIndicatorHandle);
   IndicatorRelease(s2EMAIndicatorHandle);
}


bool populateRSIOBOSPrices() {
   //--- Copy the new values of our indicators to buffers (arrays) using the handle
   if(CopyBuffer(s2RSIIndicatorHandle, 0, 0, PRICE_CLOSE, s2RSIData) < 0) {
      Alert("Error copying RSI OBOS indicator Buffers - error:", GetLastError(), ". ");
      return false;
   }

   // Get the details of the latest 3 bars
   if(CopyRates(_Symbol, chartTimeframe, 0, 3, s2SymbolPriceData) < 0) {
      Alert("Error copying rates/history data - error:", GetLastError(), ". ");
      return false;
   }
   
   // Get the EMA data for the 
   if(CopyBuffer(s2EMAIndicatorHandle, 0, 0, s2EMADataPointsToConfirmDownTrend, s2EMAData) < 0) {
      Alert("Error copying Moving Average indicator buffer - error:",GetLastError());
      return false;
   }
   
   return true;
}

bool isDownTrendConfirmed() {
   static bool trendIsDown = false;
   bool confirmation1 = true;

   // FIXME: Test using the previous candle high given the last candle bullish candle before a reversal
   if (s2SymbolPriceData[1].high > s2EMAData[0]) {
      confirmation1 = false;
   }
      
   if (confirmation1) {
      Comment("S2: EMA signalling market is in downtrend.");
      
      if (!trendIsDown && s2EnablePushNotification) {
         // SendNotification("S2 EMA Signal. Trend is down. Symbol: " + Symbol());
         // Add a visual cue
         string visualCueName = StringFormat("S2 RSI signalled Bearish at %s. \nBid price: %f. \nPrev. candle High: %f. \nEMA: %f.", (string)TimeCurrent(), latestTickPrice.bid, s2SymbolPriceData[1].high, s2EMAData[0]);
         ObjectCreate(0, visualCueName, OBJ_VLINE, 0, TimeCurrent(), s2SymbolPriceData[1].high);
         ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
         ObjectSetInteger(0, visualCueName, OBJPROP_BACK, true);
         registerChartObject(visualCueName);
      }
      
      // Set these after the notification goes out
      trendIsDown = true;
      // Print("S2: EMA signalling market is in downtrend. Flag is now ", (trendIsDown ? "True" : "False"));
   } else {
      Comment("S2: EMA signalling market is NOT in downtrend.");
      
      if (trendIsDown && s2EnablePushNotification) {
         // SendNotification("S2 EMA Signal. Trend is NOT down. Symbol: " + Symbol());
         // Add a visual cue
         string visualCueName = StringFormat("S2 RSI signalled NOT Bearish at %s. \nBid price: %f. \nPrev. candle High: %f. \nEMA: %f.", (string)TimeCurrent(), latestTickPrice.bid, s2SymbolPriceData[1].high, s2EMAData[0]);
         ObjectCreate(0, visualCueName, OBJ_VLINE, 0, TimeCurrent(), s2SymbolPriceData[1].high);
         ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
         registerChartObject(visualCueName);
      }
      
      // Set these after the notification goes out
      trendIsDown = false;
      // Print("S2: EMA signalling market is NOT in downtrend. Flag is now: " + (trendIsDown ? "True" : "False"));
   }
      
   return confirmation1;
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
   
   if (!isDownTrendConfirmed()) {
      // return;
   }
   
   if (!s2SellCondition1SignalOn && s2EnablePushNotification && s2RSIData[0] >= 78) {
      SendNotification("S2 RSI Signal. RSI is above 78 for Symbol: " + Symbol() + ". RSI: " + (string)s2RSIData[0]);
   }
   
   if (!s2SellCondition1SignalOn && s2RSIData[0] >= s2RSISignalLevel) {
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
      return; 
   }
   
   if(s2SellCondition1SignalOn) {      
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
            if(profitLoss > s2MinimumTakeProfit && s2RSIData[0] <= s2RSITakeProfitLevel) {
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

void runRSIOBOSStrategy() {
   doPlaceOrder = false;
   
   if (!populateRSIOBOSPrices()) {
      return;
   }

   closeITMPositions();
      
   if (openPositionLimitReached()){
      return;
   }

   runRSIOBOSSellStrategy();

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