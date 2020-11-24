input group "S5: Strategy 5 - Price Actions"
input double   s5MinimumTakeProfitValue = 23.0;     // Value (in currency) at which to Take Profit
input bool     s5TradeWithTrendOnly = false;       // True if new positions must follow trend direction

bool initPriceActionsIndicators() {
   // Everything provided by MarketUtils.mqh
   return true;
}

void releasePriceActionsIndicators() {
   // Everything provided by MarketUtils.mqh
}

bool populateS5Prices() {
   // Everything provided by MarketUtils.mqh
   
   return true;
}

bool runS5SellStrategy() {
   static bool s5SellCondition1SignalOn;
   static datetime s5SellCondition1TimeAtSignal;
   static double s5SellConditionPriceAtSignal;
   
   if (s5TradeWithTrendOnly && !isBearishMarket()) {
      return false;
   }
   
   if (bearishPatternsFoundCounter == 0) {
      return false;
   }
   
   // Poor mans trend check
   if (!isCurrentCandleBearish()) {
      return false;
   }
      
   if (!s5SellCondition1SignalOn) {
      s5SellCondition1SignalOn = true;
      s5SellCondition1TimeAtSignal = TimeCurrent();
      s5SellConditionPriceAtSignal = latestTickPrice.bid;
      
      // Add a visual cue
      string visualCueName = StringFormat("%s s5 signal at %s. Bearish count: %d.", signalNamePrefix, (string)s5SellCondition1TimeAtSignal, bearishPatternsFoundCounter);
      ObjectCreate(0, visualCueName, OBJ_ARROW_DOWN, 0, s5SellCondition1TimeAtSignal, latestTickPrice.bid - (100 * Point()));
      ObjectSetInteger(0, visualCueName, OBJPROP_ANCHOR, ANCHOR_TOP);
      ObjectSetInteger(0, visualCueName, OBJPROP_ALIGN, ALIGN_CENTER);
      // ObjectSetInteger(0, visualCueName, OBJPROP_FILL, true);
      ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
      registerChartObject(visualCueName);
   }

   if(s5SellCondition1SignalOn) {      
      setupGenericTradeRequest();
      mTradeRequest.type = ORDER_TYPE_SELL;
      mTradeRequest.price = NormalizeDouble(latestTickPrice.bid, _Digits);
      mTradeRequest.comment = mTradeRequest.comment + "s5 Sell conditions.";
      
      // Reset signal as all conditions have triggered and order can be placed
      s5SellCondition1SignalOn = false;
      
      return true;
   }
   
   return false;
}

bool runS5BuyStrategy() {
   static bool s5BuyCondition1SignalOn;
   static datetime s5BuyCondition1TimeAtSignal;
   static double s5BuyConditionPriceAtSignal;
   
   if (s5TradeWithTrendOnly && !isBullishMarket()) {
      return false;
   }
   
   if (bullishPatternsFoundCounter == 0) {
      return false;
   }
   
   // Poor mans trend check
   if (!isCurrentCandleBullish()) {
      return false;
   }
   
   if (!s5BuyCondition1SignalOn) {
      s5BuyCondition1SignalOn = true;
      s5BuyCondition1TimeAtSignal = TimeCurrent();
      s5BuyConditionPriceAtSignal = latestTickPrice.ask;
      
      // Add a visual cue
      string visualCueName = StringFormat("%s s5 signalled at %s. Bull count: %d.", signalNamePrefix, (string)s5BuyCondition1TimeAtSignal, bullishPatternsFoundCounter);
      ObjectCreate(0, visualCueName, OBJ_ARROW_UP, 0, s5BuyCondition1TimeAtSignal, latestTickPrice.ask - (100 * Point()));
      ObjectSetInteger(0, visualCueName, OBJPROP_ANCHOR, ANCHOR_TOP);
      ObjectSetInteger(0, visualCueName, OBJPROP_ALIGN, ALIGN_CENTER);
      // ObjectSetInteger(0, visualCueName, OBJPROP_FILL, true);
      ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
      registerChartObject(visualCueName);
      
      // Signal triggered, now wait x mins before opening the Sell position      
      return false;
   }
   
   if(s5BuyCondition1SignalOn) {      
      setupGenericTradeRequest();
      mTradeRequest.type = ORDER_TYPE_BUY;
      mTradeRequest.price = NormalizeDouble(latestTickPrice.ask, _Digits);
      mTradeRequest.comment = mTradeRequest.comment + "s5 Buy conditions.";
      
      // Reset signal as all conditions have triggered and order can be placed
      s5BuyCondition1SignalOn = false;
      
      return true;
   }
   
   return false;
}

void closeS5ITMPositions() {
   int openPositionCount = PositionsTotal(); // number of open positions
   
   for (int i = 0; i < openPositionCount; i++) {
      ulong ticket = PositionGetTicket(i); // This method selects the required position which makes the subsequent calls apply to the expected position. Something like a global pointer to the current record being queried.
      ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
      string symbol = PositionGetSymbol(i);
      double profitLoss = PositionGetDouble(POSITION_PROFIT);
      ulong  magic = PositionGetInteger(POSITION_MAGIC);
      double volume = PositionGetDouble(POSITION_VOLUME);

      if (symbol != _Symbol) {
         // This position was opened by something else. Possibly this EA but on another symbol.
         continue;
      }

      if(profitLoss >= s5MinimumTakeProfitValue) {
         PrintFormat("Close %s %s (%d): +%.2f%s.", EnumToString(positionType), symbol, ticket, profitLoss, accountCurrency);
         
         closePosition(magic, ticket, symbol, positionType, volume, StringFormat("S5 +%f (%d).", profitLoss, ticket), true);
      } else {
         // wait bit longer
         // PrintFormat("Profitable position for %s has not reached minimum TP value of %f %s - %s, Ticket: %d. Symbol: %s. Profit/Loss: %f.", _Symbol, s5MinimumTakeProfitValue, accountCurrency, EnumToString(positionType), ticket, symbol, profitLoss);
      }
   }
}

bool runPriceActionsStrategy() {
   if (!populateS5Prices()) {
      return false;
   }

   closeS5ITMPositions();
   
   if (!newOrdersPermitted()){
      // Position limit, trading disabled or daily profit target met
      return false;
   }

   if (runS5SellStrategy()){
      return tradeWithBears;
   }

   if (runS5BuyStrategy()){
      return tradeWithBulls;
   }
   
   return false;
}