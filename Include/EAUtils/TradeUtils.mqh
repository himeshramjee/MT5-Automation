//+------------------------------------------------------------------+
//|                                                   TradeUtils.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

input group "Positioning";
input double lossLimitInCurrency = 999.00; // Limit loss value per trade
input int OpenPositionsLimit = 5; // Open Positions Limit
input double lot = 2;       // Lots to Trade

// Order parameters
MqlTradeRequest mTradeRequest;   // To be used for sending our trade requests
MqlTradeResult mTradeResult;     // To be used to get our trade results
bool doPlaceOrder = false;

// Stats
int lossLimitPositionsClosedCount = 0;
double maxUsedMargin = 0.0;
double maxFloatingLoss = 0.0;

bool accountHasSufficientMargin(string symb, double lots, ENUM_ORDER_TYPE type) {

   //--- Getting the opening price
   SymbolInfoTick(_Symbol, latestTickPrice);
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
      
   PrintFormat("Margin check: Free margin is %f %s. Required Margin is %f %s. Account Margin level is %f%%.", freeMargin, accountCurrency, requiredMargin, accountCurrency, accountMarginLevel);
   
   // User does not have enough margin to take the trade
   if(requiredMargin > freeMargin) {
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

bool openPositionLimitReached() {
   if (PositionsTotal() >= OpenPositionsLimit) {
      // Print("Open Positions Limit reached. EA will only continue once open position count is less than or equal to ", OpenPositionsLimit, ". Open Positions count is ", PositionsTotal()); 
      return true;
   }
   
   double positionVolume = 0.0;
   double positionPrice = 0.0;
   double totalUsedMargin = 0.0;
   
   // Pull a margin stat before continuing
   int openPositionCount = PositionsTotal(); // number of open positions
   for (int i = 0; i < openPositionCount; i++) { 
      string symbol = PositionGetSymbol(i);
      positionVolume = PositionGetDouble(POSITION_VOLUME);
      positionPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      
      totalUsedMargin += (positionPrice * positionVolume) / accountLeverage;  
   }
   
   if (totalUsedMargin > maxUsedMargin) {
      maxUsedMargin = totalUsedMargin;
   }
   
   return false;
}

void closePositionsAboveLossLimit() {
   int openPositionCount = PositionsTotal(); // number of open positions
   double totalFloatingLoss = 0.0;
   double totalRealizedLosses = 0.0;
   
   for (int i = 0; i < openPositionCount; i++) { 
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetSymbol(i);
      double profitLoss = PositionGetDouble(POSITION_PROFIT);
      ulong  magic = PositionGetInteger(POSITION_MAGIC);
      double volume = PositionGetDouble(POSITION_VOLUME);
      ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);    

      if(profitLoss <= (lossLimitInCurrency * -1)) {
         // Loss is over user set limit so close the position
         PrintFormat("Closing loss position - %s, Ticket: %d. Symbol: %s. Profit/Loss: %f <= %f", EnumToString(positionType), ticket, symbol, profitLoss, lossLimitInCurrency * -1);
         closePosition(magic, ticket, symbol, positionType, volume);
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
   
   if (lossLimitPositionsClosedCount > 0) {
      PrintFormat("Closed %d %s positions that were above loss limit value of %f. There are currently %d open positions. Floating loss is %f %s.", lossLimitPositionsClosedCount, _Symbol, PositionsTotal(), totalFloatingLoss, accountCurrency);
   }
}

bool closePosition(ulong magic, ulong ticket, string symbol, ENUM_POSITION_TYPE positionType, double volume) {
   if(magic == EAMagic) {
      setupGenericTradeRequest();
      
      //--- setting the operation parameters
      mTradeRequest.position = ticket;          // ticket of the position
      mTradeRequest.symbol = symbol;          // symbol 
      mTradeRequest.volume = volume;                   // volume of the position
      mTradeRequest.deviation = 5;                        // allowed deviation from the price
            
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
      
      PrintFormat("Closed Position - retcode=%u  deal=%I64u  order=%I64u  ticket=%I64d.", mTradeResult.retcode, mTradeResult.deal, mTradeResult.order, ticket);
   }
   
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
}

bool sendOrder() {
   PrintFormat("Sending Order: Filling Mode: %s.", EnumToString(mTradeRequest.type_filling));
   
   if (OrderSend(mTradeRequest, mTradeResult)) {
      // Basic validation passed so check returned result now
      // Request is completed or order placed 
      if(mTradeResult.retcode == 10009 || mTradeResult.retcode == 10008) {
         // TODO: buyTickets[next] = mTradeResult.order;
         Print("A new order has been successfully placed with Ticket#:", mTradeResult.order, ". ");
         return true;
      } else {
         Print("Unexpected Order result code. New order may not have been created. mTradeResult.retcode is: ", mTradeResult.retcode, ".");
      }
   } else {
      Print(StringFormat("New order request could not be completed. Error: %d. Result comment: %s.", GetLastError(), mTradeResult.comment));
      ResetLastError();
   }
   
   return false;
}