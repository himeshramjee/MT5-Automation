input group "Positioning (All strategies)";
input bool tradeWithBears = true;            // Allow Sell positions
input bool tradeWithBulls = false;           // Allow Buy positions
input datetime dontTradeUntilDatetime;       // Start time for live trading

input int openPositionsLimit = 3;            // Open Positions Limit
input double lotSize = 2.0;                  // Lots to Trade
input double minimumRequiredEquity = 250.0;  // Minimum required equity to trade
input bool closeEachDay = true;              // True to close open trades each day, else False

input double fixedLossLimit = 5.0;           // Fixed loss limit per trade. e.g. 20usd
input double percentageLossLimit = 0.3;      // % loss limit per trade. e.g. 1 % of equity

input double dailyProfitTarget = 9999.0;     // Daily profit target
input double dailyLossLimit = 9999.0;        // Daily loss limit

bool enterWithFloatingLosses = true;         // Open new positions if floating losses

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
int profitableDaysCounter = 0;
int lossDaysCounter = 0;
double leastProfitOnADay = 9999999.0;
double highestLossOnADay = -9999999.0;
int daysBelowProfitTargetCounter = 0;

bool initTradeUtils() {
   Print("\nConfirming EA user configuration...");
   PrintFormat("HelloEA won't trade until time: %s.", TimeToString(dontTradeUntilDatetime));
   PrintFormat("Only trade if account equity is > %.2f %s.", minimumRequiredEquity, accountCurrency);
   PrintFormat("Trading for the day will stop once daily profit limit of %.2f %s is reached.", dailyProfitTarget, accountCurrency);
   PrintFormat("Trading for the day will stop once daily loss limit of %.2f %s is reached.", dailyLossLimit, accountCurrency);
   
   return true;
}

bool accountHasSufficientMargin(string symb, double lots, ENUM_ORDER_TYPE type) {
   double price = latestTickPrice.ask;
   
   if (type == ORDER_TYPE_SELL) {
      price = latestTickPrice.bid;
   }

   //--- values of the required and free margin
   double requiredMargin, freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double accountMarginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   
   //--- call of the checking function   
   if(!OrderCalcMargin(type, _Symbol, lots, price, requiredMargin)) {
      Print("Error in ",__FUNCTION__," code=", GetLastError());

      return false;
   }
      
   // PrintFormat("Margin check: Free margin is %f %s. Required Margin is %f %s. Account Margin level is %f%%.", freeMargin, accountCurrency, requiredMargin, accountCurrency, accountMarginLevel);
   
   // User does not have enough margin to take the trade
   if(requiredMargin > freeMargin) {
      insufficientMarginCount++;
      // PrintFormat("Not enough money for %s %f lots of %s (Error code = %d). Required margin is %f %s. Free Margin is %f %s. Account Margin Level is %f%%.", EnumToString(type), lots, _Symbol, GetLastError(), requiredMargin, accountCurrency, freeMargin, accountCurrency, accountMarginLevel);      
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
      ulong ticket = PositionGetTicket(i);
      positionVolume = PositionGetDouble(POSITION_VOLUME);
      positionPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      
      totalUsedMargin += (positionPrice * positionVolume) / accountLeverage;  
   }
   
   if (totalUsedMargin > maxUsedMargin) {
      maxUsedMargin = totalUsedMargin;
   }
}

bool newOrdersPermitted() {
   // Check user specified time to start trading
   datetime timeNow = TimeCurrent();
   if (timeNow < dontTradeUntilDatetime) {
      return false;
   }
   
   // Check value of open positions
   bool openPositionsExist = false;
   double valueOfOpenPositionsForSymbol = valueOfOpenPositionsForSymbol(_Symbol, openPositionsExist);
   if (!enterWithFloatingLosses && openPositionsExist && valueOfOpenPositionsForSymbol < 0) {
      // PrintFormat("Value of open positions is %.2f <= %.2f and so no new positions will be entered.", valueOfOpenPositionsForSymbol, 5);
      return false;
   }

   // Check account has sufficient margin
   static bool marginCheckPassed = false;
   bool currentMarginCheck = accountHasSufficientMargin(_Symbol, lotSize, mTradeRequest.type);
   if (!marginCheckPassed && currentMarginCheck) {
      marginCheckPassed = true;
      Print("Sufficient margin in account. New orders will be created.");
   }
   
   if (marginCheckPassed && !currentMarginCheck) {
      marginCheckPassed = false;
      Print("Insufficient margin in account. New orders will not be created.");
   }

   // Check minimum required equity
   double currentAccountEquity = NormalizeDouble(AccountInfoDouble(ACCOUNT_EQUITY), 2);
   static bool equityProtectionIsActive = false;
   if (!equityProtectionIsActive && currentAccountEquity < minimumRequiredEquity) {
      equityProtectionIsActive = true;
      PrintFormat("Equity protection enabled. Minimum Required Equity of %.2f %s isn't available. Current equity is %.2f %s. ", minimumRequiredEquity, accountCurrency, currentAccountEquity, accountCurrency);
   }
  
   if (equityProtectionIsActive && currentAccountEquity > minimumRequiredEquity) {
      PrintFormat("Equity protection disabled. Minimum Required Equity of %.2f %s is now available. Current equity is %.2f %s. ", minimumRequiredEquity, accountCurrency, currentAccountEquity, accountCurrency);
      equityProtectionIsActive = false;
   }

   return tradingEnabled && marginCheckPassed && !equityProtectionIsActive && checkDailyTargetsAreOpen() && !openPositionLimitReached();
}

bool checkDailyTargetsAreOpen() {
   static bool dayIsClosed = false;
   static bool targetsMet = false;
   static double accountBalanceAtStartOfDay = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE), 2);
   double currentAccountEquity = NormalizeDouble(AccountInfoDouble(ACCOUNT_EQUITY), 2);
   double profitLoss = currentAccountEquity - accountBalanceAtStartOfDay;
   
   if (isDayEnding() && !dayIsClosed) {
      PrintFormat("Trade targets: End of trading day. P/L: %.2f %s.", profitLoss, accountCurrency);
      
      if (profitLoss > 0) {
         profitableDaysCounter++;
         if (profitLoss < dailyProfitTarget) {
            daysBelowProfitTargetCounter++;
         }
         if (profitLoss < leastProfitOnADay) {
            leastProfitOnADay = profitLoss;
         }
      } else {
         if (profitLoss < 0) {
            lossDaysCounter++;
            
            if (profitLoss > highestLossOnADay) {
               highestLossOnADay = profitLoss;
            }
         }
      }
      
      if (closeEachDay) {
         closeAllPositions();
      }
      
      // Reset for new day
      accountBalanceAtStartOfDay = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE), 2);      
      dayIsClosed = true;
      targetsMet = false;
      PrintFormat("\nTrade targets: Next trading day with start with %.2f %s as opening balance.", accountBalanceAtStartOfDay, accountCurrency);
      
      return false;
   } else if (dayIsClosed && isNewDay()) {
      // Reopen the day. This is needed in case where this method is still called for each tick rather than each candle bar for example.
      dayIsClosed = false;
      targetsMet = false;
   }

   // EA keeps running waiting for new day so don't keep checking targets   
   if (targetsMet) {
      return false;
   }
   
   if (profitLoss >= dailyProfitTarget) {
      PrintFormat("\nTrade targets: Trading paused. Daily profit target of %.2f %s has been met. Closing all positions as current profit is %.2f %s.", dailyProfitTarget, accountCurrency, profitLoss, accountCurrency);
      targetsMet = true;
      closeAllPositions();
      return false;
   } else if (profitLoss <= (dailyLossLimit * -1)) {
      PrintFormat("\nTrade targets: Trading paused as daily loss limit of %.2f %s has been reached. Closing all positions as current loss is %.2f %s.", dailyLossLimit * -1, accountCurrency, profitLoss, accountCurrency);
      targetsMet = true;
      closeAllPositions();
      return false;
   }
   
   return true;
}

void closeAllPositions() {
   int positionsClosed = 0;
   int totalPositions = PositionsTotal();
   
   for (int i = 0; i < totalPositions; i++) { 
      ulong ticket = PositionGetTicket(i);
      ulong  magic = PositionGetInteger(POSITION_MAGIC);
      if (magic == EAMagic) {
         closePosition(magic, ticket, PositionGetSymbol(i), (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE), PositionGetDouble(POSITION_VOLUME), "Closing all positions.", PositionGetDouble(POSITION_PROFIT) > 0 ? true : false);
         positionsClosed++;
      }
   }
   
   if (positionsClosed > 0) {
      PrintFormat("Closed %d positions (probably due to daily P/L limits being reached).", positionsClosed);
   }
}

double valueOfOpenPositionsForSymbol(string symbol, bool &openPositionsExit) {
   int openPositionsForSymbolCount = 0;
   int totalPositions = PositionsTotal();
   double totalProfitLossForSymbol = 0.0;
   
   for (int i = 0; i < totalPositions; i++) { 
      ulong ticket = PositionGetTicket(i);
      
      if (EAMagic == PositionGetInteger(POSITION_MAGIC) && symbol == PositionGetSymbol(i)) {
         openPositionsForSymbolCount++;
         totalProfitLossForSymbol += PositionGetDouble(POSITION_PROFIT);
      }
   }
   
   openPositionsExit = openPositionsForSymbolCount > 0;
   
   return totalProfitLossForSymbol;
}

bool openPositionLimitReached() {
   int openPositionsByEACount = 0;
   int totalPositions = PositionsTotal();
   
   for (int i = 0; i < totalPositions; i++) { 
      ulong ticket = PositionGetTicket(i);
      ulong  magic = PositionGetInteger(POSITION_MAGIC);
      if (magic == EAMagic) {
         openPositionsByEACount++;
      }
   }
   
   if (openPositionsByEACount >= openPositionsLimit) {
      // Print("Open Positions Limit reached. EA will only continue once open position count is less than or equal to ", openPositionsLimit, ". Open Positions count is ", PositionsTotal()); 
      return true;
   }
   
   //Print("Open position limit not reached. Go forth and trade, kind sir!");
   return false;
}

void closePositionsAboveLossLimit() {
   if (!tradingEnabled) {
      return;
   }

   int openPositionCount = PositionsTotal();
   double totalFloatingLoss = 0.0;
   double totalRealizedLosses = 0.0;
   string commentToAppend;
   
   double profitLoss = 0.0;
   double volume = 0.0;
   double accountEquity = 0.0;
   double lossLimitInCurrency = 0.0;
   
   for (int i = 0; i < openPositionCount; i++) {
      ulong ticket = PositionGetTicket(i);
      ulong  magic = PositionGetInteger(POSITION_MAGIC);
      if (magic != EAMagic) {
         continue;
      }
      string symbol = PositionGetSymbol(i);
      if (symbol != _Symbol) {
         // This position was opened by something else. Possibly this EA but on another symbol.
         continue;
      }
      
      profitLoss = PositionGetDouble(POSITION_PROFIT);
      volume = PositionGetDouble(POSITION_VOLUME);
      ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);
      
      accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      lossLimitInCurrency = fixedLossLimit > 0 ? fixedLossLimit * -1 : (percentageLossLimit > 0 ? accountEquity * (percentageLossLimit / 100) * -1.0 : 0);
      
      // FIXME: Not accounting for slippage
      if (profitLoss <= lossLimitInCurrency) {
         // Loss is over user set limit so close the position
         commentToAppend = StringFormat("%s-%d: -%.2f%s (> %.2f)", positionType == POSITION_TYPE_BUY ? "Buy" : "Sell", ticket, profitLoss, accountCurrency, lossLimitInCurrency);
         Print(commentToAppend);
         
         closePosition(magic, ticket, symbol, positionType, volume, commentToAppend, false);
         lossLimitPositionsClosedCount++;
         totalRealizedLosses += profitLoss;
      } else if (profitLoss < 0) {
         // Still floating this loss
         totalFloatingLoss += profitLoss;
         // PrintFormat("Floating loss on position (ticket %d) is %.2f %s. Running floating loss for open positions is %.2f %s", ticket, profitLoss, accountCurrency, totalFloatingLoss, accountCurrency);
      }
   }
   
   if (totalFloatingLoss < maxFloatingLoss) {
      // Store the highest floating loss
      maxFloatingLoss = totalFloatingLoss;
      // Print("New floating loss high: ", maxFloatingLoss);
   }
}

bool closePosition(ulong magic, ulong ticket, string symbol, ENUM_POSITION_TYPE positionType, double volume, string commentToAppend, bool profitable) {
   if (!tradingEnabled) {
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
   
   string visualCueName = StringFormat("%s Close position for ticket %d", signalNamePrefix, ticket);
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
   if (!tradingEnabled) {
      return false;
   }
     
   // Do we have enough cash to place an order?
   if (!isClosingOrder && !accountHasSufficientMargin(_Symbol, lotSize, mTradeRequest.type)) {
      Print("Insufficient funds in account. New orders will not be created.");
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