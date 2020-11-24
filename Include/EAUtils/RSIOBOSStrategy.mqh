input group "S2: Strategy 2 - RSI OB/OS"
input double            s2RSISignalLevel = 78.0;            // RSI level to trigger new order signal
input double            s2RSITakeProfitLevel = 30.0;        // RSI level to trigger Take Profit
input bool              s2EnablePushNotification = false;   // Enable signal push notifications
input double            s2MinimumTakeProfit = 1.80;         // Minimum required TP in currency
input int               s2RSIPeriod = 18;                   // RSI Period
input bool              tradeWithinOBOSLevels = false;      // Trade within RSI level, else outside them

ENUM_TIMEFRAMES s2ChartTimeframe = PERIOD_M1;
ENUM_TIMEFRAMES s2EMATimeframe = PERIOD_M1;

// RSI Indicator
int      s2RSIIndicatorHandle;
double   s2RSIData[];
double   s2RSICurrentValue = 0.0;

bool     s2ConfirmSpotPrice = true;          // Open new position after confirming spot price

bool initRSIOBOSIndicators() {
   //--- Get handle for RSI indicator
   // NULL and 0 are the Symbol and Timeframe values respectively and values returned are from the currently active chart
   s2RSIIndicatorHandle = iRSI(NULL, s2ChartTimeframe, s2RSIPeriod, PRICE_CLOSE);
   
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
   //--- Copy the new values of our indicators to buffers (arrays) using the handle
   if(CopyBuffer(s2RSIIndicatorHandle, 0, 0, PRICE_CLOSE, s2RSIData) < 0) {
      Alert("Error copying RSI OBOS indicator Buffers - error:", GetLastError(), ". ");
      return false;
   }
   
   // Set new RSI indicator value
   s2RSICurrentValue = s2RSIData[0];
   
   return true;
}

bool rsiOBOSOrderConditionMet(ENUM_POSITION_TYPE positionType) {

   if (positionType == POSITION_TYPE_SELL) {
      if (!spotPriceIsAtArmsLength(true)) {
         return false;
      }
   
      if (!tradeWithinOBOSLevels && s2RSIData[0] >= s2RSISignalLevel) {
         return true;
      }
      
      if (tradeWithinOBOSLevels && s2RSIData[0] <= s2RSISignalLevel && s2RSIData[0] > 50) {
         return true;
      }
   }
   
   if (positionType == POSITION_TYPE_BUY) {
      if (!spotPriceIsAtArmsLength(false)) {
         return false;
      }
      
      if (!tradeWithinOBOSLevels && s2RSIData[0] <= s2RSISignalLevel) {
         return true;
      }
      
      if (tradeWithinOBOSLevels && s2RSIData[0] >= s2RSISignalLevel && s2RSIData[0] < 50) {
         return true;
      }
   }
   
   return false;
}

bool rsiOBOSProfitConditionMet(ENUM_POSITION_TYPE positionType) {
   if (positionType == POSITION_TYPE_SELL) {
      if (!spotPriceIsAtArmsLength(true)) {
         return false;
      }
      
      if (!tradeWithinOBOSLevels && s2RSIData[0] <= s2RSITakeProfitLevel) {
         return true;
      }
      
      if (tradeWithinOBOSLevels && s2RSIData[0] <= s2RSITakeProfitLevel) {
         return true;
      }
   }
   
   if (positionType == POSITION_TYPE_BUY) {
      if (!spotPriceIsAtArmsLength(false)) {
         return false;
      }
      
      if (!tradeWithinOBOSLevels && s2RSIData[0] >= s2RSITakeProfitLevel) {
         return true;
      }
      
      if (tradeWithinOBOSLevels && s2RSIData[0] >= s2RSITakeProfitLevel) {
         return true;
      }
   }
   
   return false;
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
      
   if (!s2SellCondition1SignalOn && s2EnablePushNotification && rsiOBOSOrderConditionMet(POSITION_TYPE_SELL)) {
      SendNotification("S2 RSI SELL Signal is above 78 for Symbol: " + Symbol() + ". RSI: " + (string)s2RSIData[0]);
   }
   
   if (!s2SellCondition1SignalOn && rsiOBOSOrderConditionMet(POSITION_TYPE_SELL)) {
      // Print("S2 RSI SELL  Signal is active for Symbol: " + Symbol() + ". RSI: " + (string)s2RSIData[0]);
      s2SellCondition1SignalOn = true;
      s2SellCondition1TimeAtSignal = TimeCurrent();
      s2SellConditionPriceAtSignal = latestTickPrice.bid;
      
      // Add a visual cue
      string visualCueName = StringFormat("S2 RSI SELL  signalled at %s. Bid price: %f.", (string)s2SellCondition1TimeAtSignal, latestTickPrice.bid);
      ObjectCreate(0, visualCueName, OBJ_ARROW_DOWN, 0, TimeCurrent(), latestTickPrice.bid);
      ObjectSetInteger(0, visualCueName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
      ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
      registerChartObject(visualCueName);
      
      // Signal triggered, now wait x ticks/mins before opening the Sell position      
      return false;
   }
   
   if(s2SellCondition1SignalOn) {      
      if (s2ConfirmSpotPrice && (s2SellConditionPriceAtSignal < latestTickPrice.bid)) {
         // PrintFormat("S2 RSI SELL  Signal was active but bid price is now higher than at signal time. Sell position will not be opened. Signal at %f is < current bid of %f. Resetting signal flag to false.", s2SellConditionPriceAtSignal, latestTickPrice.bid);
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

/*
   Check for a Long/Buy Setup : 
      Trend?
      RSI > y%
*/
bool runRSIOBOSBuyStrategy() {
   static bool s2BuyCondition1SignalOn;
   static datetime s2BuyCondition1TimeAtSignal;
   static double s2BuyConditionPriceAtSignal;
      
   if (!s2BuyCondition1SignalOn && s2EnablePushNotification && rsiOBOSOrderConditionMet(POSITION_TYPE_BUY)) {
      SendNotification("S2 RSI BUY Signal is above " + (string)s2RSISignalLevel + " for Symbol: " + Symbol() + ". RSI: " + (string)s2RSIData[0]);
   }
   
   if (!s2BuyCondition1SignalOn && rsiOBOSOrderConditionMet(POSITION_TYPE_BUY)) {
      // Print("S2 RSI BUY Signal is active for Symbol: " + Symbol() + ". RSI: " + (string)s2RSIData[0]);
      s2BuyCondition1SignalOn = true;
      s2BuyCondition1TimeAtSignal = TimeCurrent();
      s2BuyConditionPriceAtSignal = latestTickPrice.ask;
      
      // Add a visual cue
      string visualCueName = StringFormat("S2 RSI BUY signalled at %s. Ask price: %f.", (string)s2BuyCondition1TimeAtSignal, latestTickPrice.ask);
      ObjectCreate(0, visualCueName, OBJ_ARROW_DOWN, 0, TimeCurrent(), latestTickPrice.ask);
      ObjectSetInteger(0, visualCueName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
      ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
      registerChartObject(visualCueName);
      
      // Signal triggered, now wait x ticks/mins before opening the Buy position      
      return false;
   }
   
   if(s2BuyCondition1SignalOn) {      
      if (s2ConfirmSpotPrice && (s2BuyConditionPriceAtSignal > latestTickPrice.ask)) {
         // PrintFormat("S2 RSI BUY Signal was active but ask price is now lower than at signal time. Buy position will not be opened. Signal at %f is > current ask of %f. Resetting signal flag to false.", s2BuyConditionPriceAtSignal, latestTickPrice.ask);
         // Reset signal as all conditions have triggered, no order can be placed
         s2BuyCondition1SignalOn = false;
         return false;
      }
            
      setupGenericTradeRequest();
      mTradeRequest.type = ORDER_TYPE_BUY;                                         // Buy Order
      mTradeRequest.price = NormalizeDouble(latestTickPrice.ask, _Digits);           // latest Ask price
      mTradeRequest.comment = mTradeRequest.comment + "S2 Buy conditions.";
      
      // Reset signal as all conditions have triggered and order can be placed
      s2BuyCondition1SignalOn = false;
      
      return true;
   }
   
   return false;
}

void closeRSIOBOSITMPositions() {
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
         bool rsiAtTPLevel = false;
         if (positionType == POSITION_TYPE_SELL && rsiOBOSProfitConditionMet(POSITION_TYPE_SELL)) {
            rsiAtTPLevel = true;
         } else if (positionType == POSITION_TYPE_BUY && rsiOBOSProfitConditionMet(POSITION_TYPE_BUY)) {
            rsiAtTPLevel = true;
         }
         
         if(profitLoss >= s2MinimumTakeProfit || (profitLoss > 0 && rsiAtTPLevel)) {
            PrintFormat("Close %s %s (%d): +%.2f%s. RSI: %.2f.", EnumToString(positionType), symbol, ticket, profitLoss, accountCurrency, s2RSIData[0]);
            
            closePosition(magic, ticket, symbol, positionType, volume, StringFormat("S2 +%f (%d).", profitLoss, ticket), true);
         } else {
            // wait bit longer
            return;
         }
      }
   }
}

bool runRSIOBOSStrategy(bool newBarUp) {
   closeRSIOBOSITMPositions();
   
   if (!newOrdersPermitted() || !newBarUp) {
      return false;
   }
   
   if (!populateRSIOBOSPrices()) {
      return false;
   }

   if (tradeWithBears && tradeWithBulls) {
      PrintFormat("[S2: RSI - OB/OS] EA Sell and Buy orders cannot be enabled on the same chart. Please update your EA configuration to only enable one type of position per chart.");
      return false;
   }

   if (tradeWithBears && !tradeWithBulls) {
      return runRSIOBOSSellStrategy();
   }

   if (tradeWithBulls && !tradeWithBears) {
      return runRSIOBOSBuyStrategy();
   }
   
   return false;
}