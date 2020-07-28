input group "S5: Strategy 5 - Price Actions"
input double            s5MinimumTakeProfitValue = 5.0;     // Value (in currency) at which to Take Profit

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
   
   if (!isBearishMarket()) {
      return false;
   }
   
   if (bearishPatternsFoundCounter == 0) {
      return false;
   }
   
   if (!s5SellCondition1SignalOn) {
      s5SellCondition1SignalOn = true;
      s5SellCondition1TimeAtSignal = TimeCurrent();
      s5SellConditionPriceAtSignal = latestTickPrice.bid;
      
      // Add a visual cue
      string visualCueName = StringFormat("%s s5 signal at %s. BearishPattern count: %d.", signalNamePrefix, (string)s5SellCondition1TimeAtSignal, bearishPatternsFoundCounter);
      ObjectCreate(0, visualCueName, OBJ_ARROW_DOWN, 0, s5SellCondition1TimeAtSignal, latestTickPrice.bid + (50 * Point()));
      ObjectSetInteger(0, visualCueName, OBJPROP_ANCHOR, ANCHOR_TOP);
      ObjectSetInteger(0, visualCueName, OBJPROP_ALIGN, ALIGN_CENTER);
      ObjectSetInteger(0, visualCueName, OBJPROP_FILL, true);
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
   return false;
   
   static bool s5BuyCondition1SignalOn;
   static datetime s5BuyCondition1TimeAtSignal;
   static double s5BuyConditionPriceAtSignal;
   
   if (!isBullishMarket()) {
      return false;
   }
   
   if (bullishPatternsFoundCounter == 0) {
      return false;
   }
   
   if (!s5BuyCondition1SignalOn) {
      s5BuyCondition1SignalOn = true;
      s5BuyCondition1TimeAtSignal = TimeCurrent();
      s5BuyConditionPriceAtSignal = latestTickPrice.ask;
      
      // Add a visual cue
      string visualCueName = StringFormat("%s s5 signalled at %s. Ask price: %f.", signalNamePrefix, (string)s5BuyCondition1TimeAtSignal, latestTickPrice.ask);
      ObjectCreate(0, visualCueName, OBJ_ARROW_UP, 0, s5BuyCondition1TimeAtSignal, latestTickPrice.ask + (20 * Point()));
      ObjectSetInteger(0, visualCueName, OBJPROP_ANCHOR, ANCHOR_TOP);
      ObjectSetInteger(0, visualCueName, OBJPROP_ALIGN, ALIGN_CENTER);
      ObjectSetInteger(0, visualCueName, OBJPROP_FILL, true);
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
      ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);

      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetSymbol(i);
      double profitLoss = PositionGetDouble(POSITION_PROFIT);
      ulong  magic = PositionGetInteger(POSITION_MAGIC);
      double volume = PositionGetDouble(POSITION_VOLUME);
      
      // Only act on positions opened by this EA
      if (magic == EAMagic) {
         if (positionType == POSITION_TYPE_SELL) {
            if(profitLoss >= s5MinimumTakeProfitValue) {
               PrintFormat("Close profitable position for %s - %s, Ticket: %d. Symbol: %s. Profit/Loss: %f.", _Symbol, EnumToString(positionType), ticket, symbol, profitLoss);
               
               closePosition(magic, ticket, symbol, positionType, volume, "s5 profit conditions.", true);
            } else {
               // wait bit longer
               return;
            }
         }
      }
   }
}

bool runPriceActionsStrategy() {
   if (!populateS5Prices()) {
      return false;
   }

   closeS5ITMPositions();
      
   if (openPositionLimitReached()){
      return false;
   }

   if (runS5BuyStrategy()){
      return true;
   }
   
   if (runS5SellStrategy()){
      return true;
   }
   
   return false;
}