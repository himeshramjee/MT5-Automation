//+------------------------------------------------------------------+
//|                                                   TradeUtils.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

// Order parameters
MqlTradeRequest mTradeRequest;   // To be used for sending our trade requests
MqlTradeResult mTradeResult;     // To be used to get our trade results

bool ValidateFreeMargin(string symb, double lots, ENUM_ORDER_TYPE type) {
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
      Print("Not enough money for ",EnumToString(type)," ",lots," ",symb," Error code=",GetLastError());
      
      // FIXME: Method call?
      return(false);
   }
   
   // FIXME: Method call?
   return(true);
}

// TODO: Note this example uses the pointer reference for description.
bool ValidateOrderVolume(double volume, string &description) {
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

ENUM_ORDER_TYPE_FILLING GetOrderFillMode() {
   //--- Obtain the value of the property that describes allowed filling modes
   int filling = (int) SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   
   if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) {
      return ORDER_FILLING_IOC;
   }
   
   return ORDER_FILLING_FOK;
}

bool accountHasOpenPositions() {
   return PositionSelect(_Symbol) == true;
   /*
   if (PositionSelect(_Symbol) == true) {
      // we have an opened position, now check the type
      if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
         buyOpened = true;
      }
      
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
         sellOpened = true;
      }
   }
   */
}

void setupGenericTradeRequest() {
   // Set generic order info
   ZeroMemory(mTradeRequest);       // Initialization of mrequest structure
   
   mTradeRequest.action = TRADE_ACTION_DEAL;                                    // immediate order execution
   mTradeRequest.symbol = _Symbol;                                              // currency pair
   mTradeRequest.volume = Lot;                                                  // number of lots to trade
   mTradeRequest.magic = EAMagic;                                              // Order Magic Number
   mTradeRequest.type_filling = GetOrderFillMode();
   mTradeRequest.deviation = 100;                                                 // Deviation from current price
   mTradeRequest.type = NULL;
}

void makeMoney() {
   if (OrderSend(mTradeRequest, mTradeResult)) {
      // Basic validation passed so check returned result now
      // Request is completed or order placed 
      if(mTradeResult.retcode == 10009 || mTradeResult.retcode == 10008) {
         // TODO: buyTickets[next] = mTradeResult.order;
         Print("A new order has been successfully placed with Ticket#:", mTradeResult.order, ". ");
      } else {
         // TODO: Post to journal
         Print("Unexpected Order result code. Buy order may not have been created. mTradeResult.retcode is: ", mTradeResult.retcode, ".");
         return;
      }
   } else {
      // TODO: Post to journal
      int errorCode = GetLastError();
      Print(StringFormat("New order request could not be completed. Error: %d. Result comment: %s.", errorCode, mTradeResult.comment));
      ResetLastError();
      return;
   }
}