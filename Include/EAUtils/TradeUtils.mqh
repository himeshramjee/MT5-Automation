input group "Positioning (All strategies)";
input double lossLimitInCurrency = 50; // Limit loss value per trade
input int openPositionsLimit = 2; // Open Positions Limit
input double lot = 0.2;       // Lots to Trade

// Order parameters
MqlTradeRequest mTradeRequest;   // To be used for sending our trade requests
MqlTradeResult mTradeResult;     // To be used to get our trade results
MqlTick latestTickPrice;         // To be used for getting recent/latest price quotes

bool doPlaceOrder = false;

// Stats
int lossLimitPositionsClosedCount = 0;
double maxUsedMargin = 0.0;
double maxFloatingLoss = 0.0;
int insufficientMarginCount = 0;

bool setTickPricing() {
   // Get the last price quote using the MQL5 MqlTick Structure
   if(!SymbolInfoTick(_Symbol, latestTickPrice)) {
      Alert("Error getting the latest price quote - error:", GetLastError(), ". ");
      return false;
   }
      
   return true;
}

bool accountHasSufficientMargin(string symb, double lots, ENUM_ORDER_TYPE type) {
   double price = latestTickPrice.ask;
   
   if (type == ORDER_TYPE_SELL) {
      price = latestTickPrice.bid;
   }

   //--- values of the required and free margin
   double requiredMargin, freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   accountMarginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   
   //--- call of the checking function   
   if(!OrderCalcMargin(type, _Symbol, lots, price, requiredMargin)) {
      Print("Error in ",__FUNCTION__," code=", GetLastError());

      return(false);
   }
      
   // PrintFormat("Margin check: Free margin is %f %s. Required Margin is %f %s. Account Margin level is %f%%.", freeMargin, accountCurrency, requiredMargin, accountCurrency, accountMarginLevel);
   
   // User does not have enough margin to take the trade
   if(requiredMargin > freeMargin) {
      insufficientMarginCount++;
      PrintFormat("Not enough money for %s %f lots of %s (Error code = %d). Required margin is %f %s. Free Margin is %f %s. Account Margin Level is %f%%.", EnumToString(type), lots, _Symbol, GetLastError(), requiredMargin, accountCurrency, freeMargin, accountCurrency, accountMarginLevel);      
      return(false);
   }
   
   // User has sufficient margin to take the trade   
   return(true);
}

// TODO: Note this example uses the pointer reference for description. Doubt it's necessary.
bool validateOrderVolume(double volume, string &description) {
   //--- minimal allowed volume for trade operations
   double min_volume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   if(volume < min_volume) {
      description = StringFormat("Volume is less than the minimal allowed SYMBOL_VOLUME_MIN=%.2f", min_volume);
      return(false);
   }

   //--- maximal allowed volume of trade operations
   double max_volume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   if(volume > max_volume) {
      description = StringFormat("Volume is greater than the maximal allowed SYMBOL_VOLUME_MAX=%.2f", max_volume);
      return(false);
   }

   //--- get minimal step of volume changing
   double volume_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

   int ratio = (int) MathRound(volume / volume_step);
   if(MathAbs(ratio * volume_step - volume) > 0.0000001) {
      description = StringFormat("Volume is not a multiple of the minimal step SYMBOL_VOLUME_STEP=%.2f, the closest correct volume is %.2f",
                               volume_step,ratio*volume_step);
      return(false);
   }
   
   description = StringFormat("Correct volume value (%.2f)", volume);
   
   return(true);
}

ENUM_ORDER_TYPE_FILLING getOrderFillMode() {
   //--- Obtain the value of the property that describes allowed filling modes
   int filling = (int) SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
      
   if(filling == SYMBOL_FILLING_FOK) {
      return ORDER_FILLING_FOK;
   }
   
   return ORDER_FILLING_IOC;
}

void calculateMaxUsedMargin() {
   double positionVolume = 0.0;
   double positionPrice = 0.0;
   double totalUsedMargin = 0.0;
   
   // Pull a margin stat before continuing
   int openPositionCount = PositionsTotal(); // number of open positions
   for (int i = 0; i < openPositionCount; i++) { 
      positionVolume = PositionGetDouble(POSITION_VOLUME);
      positionPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      
      totalUsedMargin += (positionPrice * positionVolume) / accountLeverage;  
   }
   
   if (totalUsedMargin > maxUsedMargin) {
      maxUsedMargin = totalUsedMargin;
   }
}

bool openPositionLimitReached() {
   int openPositionsByEACount = 0;
   
   for (int i = 0; i < PositionsTotal(); i++) { 
      ulong  magic = PositionGetInteger(POSITION_MAGIC);
      if (magic == EAMagic) {
         openPositionsByEACount++;
      }
   }
   
   if (openPositionsByEACount >= openPositionsLimit) {
      // Print("Open Positions Limit reached. EA will only continue once open position count is less than or equal to ", openPositionsLimit, ". Open Positions count is ", PositionsTotal()); 
      return true;
   }
   
   return false;
}

void closePositionsAboveLossLimit() {
   if (!enableEATrading) {
      return;
   }

   int openPositionCount = PositionsTotal();
   double totalFloatingLoss = 0.0;
   double totalRealizedLosses = 0.0;
   string commentToAppend;
   
   for (int i = 0; i < openPositionCount; i++) {
      // Only act on EA owned positions
      ulong  magic = PositionGetInteger(POSITION_MAGIC);
      if (magic != EAMagic) {
         continue;
      }
   
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetSymbol(i);
      double profitLoss = PositionGetDouble(POSITION_PROFIT);
      double volume = PositionGetDouble(POSITION_VOLUME);
      ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
      commentToAppend = "Limiting loss position.";

      if(profitLoss <= (lossLimitInCurrency * -1)) {
         // Loss is over user set limit so close the position
         PrintFormat("Closing loss position - %s, Ticket: %d. Symbol: %s. Profit/Loss: %f <= %f", EnumToString(positionType), ticket, symbol, profitLoss, lossLimitInCurrency * -1);
         
         closePosition(magic, ticket, symbol, positionType, volume, commentToAppend, false);
         lossLimitPositionsClosedCount++;
         totalRealizedLosses += profitLoss;
      } else if (profitLoss < 0) {
         // Still floating this loss
         totalFloatingLoss += profitLoss;
         // PrintFormat("Floating loss on position (ticket %d) is %f %s. Running floating loss for open positions is %f %s", ticket, profitLoss, accountCurrency, totalFloatingLoss, accountCurrency);
      }
   }
   
   if (totalFloatingLoss < maxFloatingLoss) {
      // Store the highest floating loss
      maxFloatingLoss = totalFloatingLoss;
      // Print("New floating loss high: ", maxFloatingLoss);
   }
}

bool closePosition(ulong magic, ulong ticket, string symbol, ENUM_POSITION_TYPE positionType, double volume, string commentToAppend, bool profitable) {
   if (!enableEATrading) {
      return false;
   }

   if (magic != EAMagic) {
      PrintFormat("EA Magic number mismatch. Close %s position (ticket#: %d) request rejected. Expected %d but got %d.", EnumToString(positionType), ticket, mTradeRequest.magic, EAMagic);
      return false;
   }
   
   setupGenericTradeRequest();
   
   //--- setting the operation parameters
   mTradeRequest.position = ticket;          // ticket of the position
   mTradeRequest.symbol = symbol;          // symbol 
   mTradeRequest.volume = volume;                   // volume of the position
   mTradeRequest.deviation = 5;                        // allowed deviation from the price"
   mTradeRequest.comment = mTradeRequest.comment + commentToAppend;
         
   //--- set the price and order type depending on the position type
   if(positionType == POSITION_TYPE_BUY) {
      mTradeRequest.price = SymbolInfoDouble(symbol,SYMBOL_BID);
      mTradeRequest.type = ORDER_TYPE_SELL;
   } else {
      mTradeRequest.price = SymbolInfoDouble(symbol,SYMBOL_ASK);
      mTradeRequest.type = ORDER_TYPE_BUY;
   }
   
   if(!sendOrder()) {
      return false;
   }
   
   string visualCueName = StringFormat("Close position for ticket %d", ticket);
   // Add a visual cue
   if (profitable) {
      ObjectCreate(0, visualCueName, OBJ_ARROW_THUMB_UP, 0, TimeCurrent(), mTradeRequest.price);
   } else {
      ObjectCreate(0, visualCueName, OBJ_ARROW_THUMB_DOWN, 0, TimeCurrent(), mTradeRequest.price);
   }
   ObjectSetInteger(0, visualCueName, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
   ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
   registerChartObject(visualCueName);
   
   // PrintFormat("Closed Position - retcode=%u  deal=%I64u  order=%I64u  ticket=%I64d.", mTradeResult.retcode, mTradeResult.deal, mTradeResult.order, ticket);
   
   return true;
}

void setupGenericTradeRequest() {
   // Set generic order info
   ZeroMemory(mTradeRequest);
   ZeroMemory(mTradeResult);
   
   mTradeRequest.action = TRADE_ACTION_DEAL;                                    // immediate order execution
   mTradeRequest.symbol = _Symbol;                                              // currency pair
   mTradeRequest.volume = lot;                                                  // number of lots to trade
   mTradeRequest.magic = EAMagic;                                              // Order Magic Number
   mTradeRequest.type_filling = getOrderFillMode();
   mTradeRequest.deviation = 5;                                                 // Deviation from current price
   mTradeRequest.type = NULL;
   // mTradeRequest.comment = "HelloEA:";
}

bool sendOrder() {
   if (!enableEATrading) {
      return false;
   }

   if (mTradeRequest.magic != EAMagic) {
      PrintFormat("EA Magic number mismatch. Send order request rejected. Expected %d but got %d.", mTradeRequest.magic, EAMagic);
   }
   
   if (OrderSend(mTradeRequest, mTradeResult)) {
      // Basic validation passed so check returned result now
      // Request is completed or order placed 
      if(mTradeResult.retcode == 10009 || mTradeResult.retcode == 10008) {
         Print("A new order has been successfully placed with Ticket#:", mTradeResult.order, ". ");
         return true;
      } else {
         Print("Unexpected Order result code. New order may not have been created. mTradeResult.retcode is: ", mTradeResult.retcode, ".");
      }
   } else {
      PrintFormat("New order request could not be completed. Ticket#: %d. Error: %d. Result comment: %s. Return code: %s.", mTradeRequest.order, GetLastError(), mTradeResult.comment, mTradeResult.retcode);
      ResetLastError();
   }
   
   return false;
}