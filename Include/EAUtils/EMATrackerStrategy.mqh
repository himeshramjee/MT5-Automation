input group "S6: Strategy 6 - EMA Tracker"

input bool              s6EnablePushNotification = false;   // Enable signal push notifications
input double            s6MinimumTakeProfit = 1.80;         // Minimum required TP in currency

bool     s6ConfirmSpotPrice = true;          // Open new position after confirming spot price

bool initEMATrackerIndicators() {
   // No op for now
   return true;
}

void releaseEMATrackerIndicators() {
   // Release indicator handles
   // No op for now
}


bool populateEMATrackerPrices() {
   // No op for now
   return true;
}

/*
   Check for a Short/Sell Setup : 
      spot price is <= some deviation from EMA
*/
bool runEMATrackerSellStrategy() {
   static bool s6SellCondition1SignalOn;
   static datetime s6SellCondition1TimeAtSignal;
   static double s6SellConditionPriceAtSignal;
   
   if (!spotPriceIsAtArmsLength(true)) {
      return false;
   }
   
   if (!s6SellCondition1SignalOn && s6EnablePushNotification && spotPriceIsAtArmsLength(true)) {
      SendNotification("S6 EMA Tracker SELL Signal is active for Symbol: " + Symbol() + ".");
   }
   
   if (!s6SellCondition1SignalOn && spotPriceIsAtArmsLength(true)) {
      // Print("S6 EMA Tracker SELL  Signal is active for Symbol: " + Symbol() + ".");
      s6SellCondition1SignalOn = true;
      s6SellCondition1TimeAtSignal = TimeCurrent();
      s6SellConditionPriceAtSignal = latestTickPrice.bid;
      
      // Add a visual cue
      string visualCueName = StringFormat("S6 EMA Tracker SELL  signalled at %s. Bid price: %f.", (string)s6SellCondition1TimeAtSignal, latestTickPrice.bid);
      ObjectCreate(0, visualCueName, OBJ_ARROW_DOWN, 0, TimeCurrent(), latestTickPrice.bid);
      ObjectSetInteger(0, visualCueName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
      ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
      registerChartObject(visualCueName);
      
      // Signal triggered, now wait x ticks/mins before opening the Sell position      
      return false;
   }
   
   if(s6SellCondition1SignalOn) {      
      if (s6ConfirmSpotPrice && (s6SellConditionPriceAtSignal < latestTickPrice.bid)) {
         // PrintFormat("S6 EMA Tracker SELL  Signal was active but bid price is now higher than at signal time. Sell position will not be opened. Signal at %f is < current bid of %f. Resetting signal flag to false.", s6SellConditionPriceAtSignal, latestTickPrice.bid);
         // Reset signal as all conditions have triggered, no order can be placed
         s6SellCondition1SignalOn = false;
         return false;
      }
      
      setupGenericTradeRequest();
      mTradeRequest.type = ORDER_TYPE_SELL;                                         // Sell Order
      mTradeRequest.price = NormalizeDouble(latestTickPrice.bid, _Digits);           // latest Bid price
      mTradeRequest.comment = mTradeRequest.comment + "S6 Sell conditions.";
      
      // Reset signal as all conditions have triggered and order can be placed
      s6SellCondition1SignalOn = false;
      
      return true;
   }
   
   return false;
}

/*
   Check for a Long/Buy Setup : 
      spot price is >= some deviation from EMA
*/
bool runEMATrackerBuyStrategy() {
   static bool s6BuyCondition1SignalOn;
   static datetime s6BuyCondition1TimeAtSignal;
   static double s6BuyConditionPriceAtSignal;
   
   if (!spotPriceIsAtArmsLength(false)) {
      return false;
   }
   
   if (!s6BuyCondition1SignalOn && s6EnablePushNotification && spotPriceIsAtArmsLength(false)) {
      SendNotification("S6 EMA Tracker BUY Signal is active for Symbol: " + Symbol() + ".");
   }
   
   if (!s6BuyCondition1SignalOn && spotPriceIsAtArmsLength(false)) {
      // Print("S6 EMA Tracker BUY  Signal is active for Symbol: " + Symbol() + ".");
      s6BuyCondition1SignalOn = true;
      s6BuyCondition1TimeAtSignal = TimeCurrent();
      s6BuyConditionPriceAtSignal = latestTickPrice.bid;
      
      // Add a visual cue
      string visualCueName = StringFormat("S6 EMA Tracker BUY signalled at %s. Ask price: %f.", (string)s6BuyCondition1TimeAtSignal, latestTickPrice.ask);
      ObjectCreate(0, visualCueName, OBJ_ARROW_DOWN, 0, TimeCurrent(), latestTickPrice.ask);
      ObjectSetInteger(0, visualCueName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
      ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
      registerChartObject(visualCueName);
      
      // Signal triggered, now wait x ticks/mins before opening the Buy position      
      return false;
   }
   
   if(s6BuyCondition1SignalOn) {      
      if (s6ConfirmSpotPrice && (s6BuyConditionPriceAtSignal < latestTickPrice.ask)) {
         // PrintFormat("S6 EMA Tracker BUY Signal was active but bid price is now higher than at signal time. Buy position will not be opened. Signal at %f is < current ask of %f. Resetting signal flag to false.", s6BuyConditionPriceAtSignal, latestTickPrice.ask);
         // Reset signal as all conditions have triggered, no order can be placed
         s6BuyCondition1SignalOn = false;
         return false;
      }
      
      setupGenericTradeRequest();
      mTradeRequest.type = ORDER_TYPE_SELL;                                         // Buy Order
      mTradeRequest.price = NormalizeDouble(latestTickPrice.ask, _Digits);           // latest Ask price
      mTradeRequest.comment = mTradeRequest.comment + "S6 Buy conditions.";
      
      // Reset signal as all conditions have triggered and order can be placed
      s6BuyCondition1SignalOn = false;
      
      return true;
   }
   
   return false;
}

void closeEMATrackerITMPositions() {
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
         if(profitLoss >= s6MinimumTakeProfit) {
            PrintFormat("Close %s %s (%d): +%.2f%s.", EnumToString(positionType), symbol, ticket, profitLoss, accountCurrency);
            
            closePosition(magic, ticket, symbol, positionType, volume, StringFormat("S6 +%f (%d).", profitLoss, ticket), true);
         } else {
            // wait bit longer
            return;
         }
      }
   }
}

bool runEMATrackerStrategy(bool newBarUp) {
   closeEMATrackerITMPositions();
   
   if (!newOrdersPermitted() || !newBarUp) {
      return false;
   }

   if (!populateEMATrackerPrices()) {
      return false;
   }
   
   if (tradeWithBears && tradeWithBulls) {
      PrintFormat("[S6: EMA Tracker] EA Sell and Buy orders cannot be enabled on the same chart. Please update your EA configuration to only enable one type of position per chart.");
      return false;
   }
   
   if (tradeWithBears && !tradeWithBulls) {
      return runEMATrackerSellStrategy();
   }

   if (tradeWithBulls && !tradeWithBears) {
      return runEMATrackerBuyStrategy();
   }
   
   return false;
}