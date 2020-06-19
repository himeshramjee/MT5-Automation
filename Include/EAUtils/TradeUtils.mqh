//+------------------------------------------------------------------+
//|                                                   TradeUtils.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

input double lossLimitInCurrency = 50.00; // Limit loss value per trade
input int OpenPositionsLimit = 5; // Open Positions Limit
input double Lot = 2;       // Lots to Trade

// Order parameters
MqlTradeRequest mTradeRequest;   // To be used for sending our trade requests
MqlTradeResult mTradeResult;     // To be used to get our trade results

bool validateFreeMargin(string symb, double lots, ENUM_ORDER_TYPE type) {
   //--- Getting the opening price
   MqlTick mqltick;
   SymbolInfoTick(symb,mqltick);
   double price=mqltick.ask;
   
   if(type==ORDER_TYPE_SELL)
      price=mqltick.bid;
   
   //--- values of the required and free margin
   double margin,free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   
   //--- call of the checking function   
   if(!OrderCalcMargin(type,symb,lots,price,margin)) {
      //--- something went wrong, report and return false
      Print("Error in ",__FUNCTION__," code=",GetLastError());
      
      // FIXME: Method call?
      return(false);
   }
   
   //--- if there are insufficient funds to perform the operation
   if(margin>free_margin) {
      //--- report the error and return false
      PrintFormat("Not enough money for %s %d %s (Error code = %d). Margin is %f. Free Margin is %f.", EnumToString(type), lots, symb, GetLastError(), margin, free_margin);
      
      // FIXME: Method call?
      return(false);
   }
   
   // FIXME: Method call?
   return(true);
}

// TODO: Note this example uses the pointer reference for description.
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
   
   if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) {
      return ORDER_FILLING_IOC;
   }
   
   return ORDER_FILLING_FOK;
}

bool openPositionLimitReached() {
   if (PositionsTotal() >= OpenPositionsLimit) {
      // Print("Open Positions Limit reached. EA will only continue once open position count is less than or equal to ", OpenPositionsLimit, ". Open Positions count is ", PositionsTotal()); 
      return true;
   }
   
   return false;
}

void closePositionsAboveLossLimit() {
   int activeLossPositionCount = 0;
   int activeProfitPositionCount = 0;
   int lossPositionsToCloseCount = 0;
   int openPositionCount = PositionsTotal(); // number of open positions
   
   for (int i = 0; i < openPositionCount; i++) { 
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetSymbol(i);
      double profitLoss = PositionGetDouble(POSITION_PROFIT);
      ulong  magic = PositionGetInteger(POSITION_MAGIC);
      double volume = PositionGetDouble(POSITION_VOLUME);
      ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);    
      
      if(profitLoss >= 1) {
         activeProfitPositionCount++;
      } else {
         activeLossPositionCount++;
      }
      
      if(profitLoss <= (lossLimitInCurrency * -1)) {
         lossPositionsToCloseCount++;
         PrintFormat("Closing loss position - %s, Ticket: %d. Symbol: %s. Profit/Loss: %f <= %f", EnumToString(positionType), ticket, symbol, profitLoss, lossLimitInCurrency * -1);
         closePosition(magic, ticket, symbol, positionType, volume);
      }
   }
}

bool closePosition(ulong magic, ulong ticket, string symbol, ENUM_POSITION_TYPE positionType, double volume) {
   if(magic == EAMagic) {
      //--- zeroing the request and result values
      ZeroMemory(mTradeRequest);
      ZeroMemory(mTradeResult);
      
      //--- setting the operation parameters
      mTradeRequest.action = TRADE_ACTION_DEAL;        // type of trade operation
      mTradeRequest.position = ticket;          // ticket of the position
      mTradeRequest.symbol = symbol;          // symbol 
      mTradeRequest.volume = volume;                   // volume of the position
      mTradeRequest.deviation = 5;                        // allowed deviation from the price
      mTradeRequest.magic = EAMagic;             // MagicNumber of the position
      
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
   mTradeRequest.volume = Lot;                                                  // number of lots to trade
   mTradeRequest.magic = EAMagic;                                              // Order Magic Number
   mTradeRequest.type_filling = getOrderFillMode();
   mTradeRequest.deviation = 100;                                                 // Deviation from current price
   mTradeRequest.type = NULL;
}

bool sendOrder() {
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