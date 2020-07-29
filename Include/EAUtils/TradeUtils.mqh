input group "Positioning (All strategies)";
input double percentageLossLimit = 10; // Loss limit per trade. e.g. 1 % of equity
input int openPositionsLimit = 3;        // Open Positions Limit
input double lotSize = 4.0;              // Lots to Trade

// Order parameters
MqlTradeRequest mTradeRequest;   // To be used for sending our trade requests
MqlTradeResult mTradeResult;     // To be used to get our trade results

// Stats
int lossLimitPositionsClosedCount = 0;
double maxUsedMargin = 0.0;
double maxFloatingLoss = 0.0;
int insufficientMarginCount = 0;
int totalSellOrderCount = 0;
int totalBuyOrderCount = 0;
int totalFailedOrderCount = 0;

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

      return false;
   }
      
   // PrintFormat("Margin check: Free margin is %f %s. Required Margin is %f %s. Account Margin level is %f%%.", freeMargin, accountCurrency, requiredMargin, accountCurrency, accountMarginLevel);
   
   // User does not have enough margin to take the trade
   if(requiredMargin > freeMargin) {
      insufficientMarginCount++;
      PrintFormat("Not enough money for %s %f lots of %s (Error code = %d). Required margin is %f %s. Free Margin is %f %s. Account Margin Level is %f%%.", EnumToString(type), lots, _Symbol, GetLastError(), requiredMargin, accountCurrency, freeMargin, accountCurrency, accountMarginLevel);      
      return false;
   }
   
   // User has sufficient margin to take the trade   
   return true;
}

// FIXME: Note this example uses the pointer reference for description. Doubt it's necessary.
bool validateOrderVolume(string &description) {
   //--- minimal allowed volume for trade operations
   double min_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(lotSize < min_volume) {
      description = StringFormat("Volume is less than the minimal allowed SYMBOL_VOLUME_MIN=%.2f", min_volume);
      return false;
   }

   //--- maximal allowed volume of trade operations
   double max_volume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(lotSize > max_volume) {
      description = StringFormat("Volume is greater than the maximal allowed SYMBOL_VOLUME_MAX=%.2f", max_volume);
      return false;
   }

   //--- get minimal step of volume changing
   double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   int ratio = (int) MathRound(lotSize / volume_step);
   if(MathAbs(ratio * volume_step - lotSize) > 0.0000001) {
      description = StringFormat("Volume is not a multiple of the minimal step SYMBOL_VOLUME_STEP=%.2f, the closest correct volume is %.2f",
                               volume_step,ratio*volume_step);
      return false;
   }
   
   description = StringFormat("Correct volume value (%.2f)", lotSize);
   
   return true;
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

      double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      double lossThreshold = accountEquity * (percentageLossLimit / 100);
      
      // FIXME: Not accounting for slippage
      if(profitLoss < 0 && profitLoss <= (lossThreshold * -1)) {
         // Loss is over user set limit so close the position
         PrintFormat("Closing loss position - %s, Ticket: %d. Symbol: %s. Profit/Loss: %f <= %f", EnumToString(positionType), ticket, symbol, profitLoss, percentageLossLimit);
         
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
   mTradeRequest.comment = mTradeRequest.comment + commentToAppend;
         
   //--- set the price and order type depending on the position type
   if(positionType == POSITION_TYPE_BUY) {
      mTradeRequest.price = SymbolInfoDouble(symbol,SYMBOL_BID);
      mTradeRequest.type = ORDER_TYPE_SELL;
   } else if (positionType == POSITION_TYPE_SELL) {
      mTradeRequest.price = SymbolInfoDouble(symbol,SYMBOL_ASK);
      mTradeRequest.type = ORDER_TYPE_BUY;
   } else {
      PrintFormat("Error: Unexpected position type %s for ticket %d and symbol %s.", EnumToString(positionType), ticket, symbol);
      return false;
   }
   
   if(!sendOrder(true)) {
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
   
   return true;
}

void setupGenericTradeRequest() {
   // Set generic order info
   ZeroMemory(mTradeRequest);
   ZeroMemory(mTradeResult);
   
   mTradeRequest.action = TRADE_ACTION_DEAL;                                    // immediate order execution
   mTradeRequest.symbol = _Symbol;                                              // currency pair
   mTradeRequest.volume = lotSize;                                                  // number of lots to trade
   mTradeRequest.magic = EAMagic;                                              // Order Magic Number
   mTradeRequest.type_filling = getOrderFillMode();
   // mTradeRequest.deviation = 5;                                                 // Deviation from current price
   mTradeRequest.type = NULL;
}

bool sendOrder(bool isClosingOrder) {
   if (!enableEATrading) {
      return false;
   }
     
   // Do we have enough cash to place an order?
   if (!accountHasSufficientMargin(_Symbol, lotSize, mTradeRequest.type)) {
      Print("Insufficient funds in account. Disable this EA until you sort that out.");
      return false;
   }

   if (mTradeRequest.magic != EAMagic) {
      PrintFormat("EA Magic number mismatch. Send order request rejected. Expected %d but got %d.", mTradeRequest.magic, EAMagic);
      totalFailedOrderCount++;
   }
   
   MqlTradeCheckResult mTradeCheckResult;
   ZeroMemory(mTradeCheckResult);
   
   if (!OrderCheck(mTradeRequest, mTradeCheckResult)) {
      PrintFormat("New%s order checks failed. Ticket#: %d. Error: %d. Result comment: %s. Return code: %d.", isClosingOrder ? " close" : "", mTradeRequest.order, GetLastError(), mTradeCheckResult.comment, mTradeCheckResult.retcode);
      totalFailedOrderCount++;
      return false;
   }
   
   if (OrderSend(mTradeRequest, mTradeResult)) {
      // Basic validation passed so check returned result now
      // Request is completed or order placed 
      if(mTradeResult.retcode == 10009 || mTradeResult.retcode == 10008) {
         Print("A new order has been successfully placed with Ticket#:", mTradeResult.order, ". ");
         
         if (!isClosingOrder) {
            if (mTradeRequest.type == ORDER_TYPE_SELL) {
               totalSellOrderCount++;
            } else if (mTradeRequest.type == ORDER_TYPE_BUY) {
               totalBuyOrderCount++;
            }
         }
         
         return true;
      } else {
         Print("Unexpected Order result code. New%s order may not have been created. mTradeResult.retcode is: ", isClosingOrder ? " CLOSE" : "", mTradeResult.retcode, ".");
         totalFailedOrderCount++;
      }
   } else {
      PrintFormat("New%s order request could not be completed. Ticket#: %d. Error: %d. Result comment: %s. Return code: %d.", isClosingOrder ? " CLOSE" : "", mTradeRequest.order, GetLastError(), mTradeResult.comment, mTradeResult.retcode);
      totalFailedOrderCount++;
      ResetLastError();
   }
   
   return false;
}