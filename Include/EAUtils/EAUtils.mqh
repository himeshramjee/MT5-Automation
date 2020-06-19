//+------------------------------------------------------------------+
//|                                                      EAUtils.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

// EA parameters
int EAMagic=10024; // EA Magic Number


bool ValidateTradingPermissions() {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
      Alert("Please enable automated trading in your client terminal. Find the 'Algo/Auto Trading' button on the toolbar.");
      return false;
   }
   
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) {
      Alert("Automated trading is forbidden in the program settings for ", __FILE__);
      return false;
   }
   
   if(!AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) {
      Alert("Automated trading is forbidden for the account ", AccountInfoInteger(ACCOUNT_LOGIN), " at the trade server side");
      return false;
   }
   
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) {
      Alert("Trading is not enabled for this account.");
      Comment("Trading is forbidden for the account ", AccountInfoInteger(ACCOUNT_LOGIN),
            ".\n Perhaps an investor password has been used to connect to the trading account.",
            "\n Check the terminal journal for the following entry:",
            "\n\'", AccountInfoInteger(ACCOUNT_LOGIN), "\': trading has been disabled - investor mode.");
      return false;
   }
   
   return true;
}

void ShowMetaInfo() {
   //--- obtain spread from the symbol properties
   bool spreadfloat=SymbolInfoInteger(Symbol(),SYMBOL_SPREAD_FLOAT);
   string comm=StringFormat("%s spread = %I64d points. ", spreadfloat?"floating":"fixed", SymbolInfoInteger(Symbol(),SYMBOL_SPREAD));
   //--- now let's calculate the spread by ourselves
   double ask=SymbolInfoDouble(Symbol(),SYMBOL_ASK);
   double bid=SymbolInfoDouble(Symbol(),SYMBOL_BID);
   double spread=ask-bid;
   int spread_points=(int)MathRound(spread/SymbolInfoDouble(Symbol(),SYMBOL_POINT));
   comm=comm+"Calculated spread = "+(string)spread_points+" points.";
   Print(comm);
}

void printSymbolInfo() {
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int spread = (int) SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   int spreadFloat = (int) SymbolInfoInteger(_Symbol, SYMBOL_SPREAD_FLOAT);
   PrintFormat("Point: %f, Spread (points): %f, SpreadFloat: %f", point, spread, spreadFloat);

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double lotSize = MathFloor(Lot/lotStep) * lotStep;
   PrintFormat("MinLots: %f.2, LotStep: %f, LotSize: %f.", minLot, lotStep, lotSize);
   
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double stopPrice = latestTickPrice.bid + ((stopLoss < tickSize ? tickSize : stopLoss) * _Point);
   double profitPrice = latestTickPrice.bid - ((takeProfit < tickSize ? tickSize : takeProfit) * _Point);
   PrintFormat("TickSize: %.5d, StopPrice: %.5d, ProfitPrice: %.5d.", tickSize, stopPrice, profitPrice);
}