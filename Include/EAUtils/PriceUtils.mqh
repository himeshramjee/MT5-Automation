//+------------------------------------------------------------------+
//|                                                   PriceUtils.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

input group "Pricing";
input bool SetStopLoss = false; // Automatically set Stop Loss
input bool SetTakeProfit = false; // Automatically set Take Profit
input int StopLoss = 0;   // Stop Loss (Pips)
input int TakeProfit = 0;// Take Profit (Pips)

int stopLoss, takeProfit;   // To be used for Stop Loss & Take Profit values
MqlTick latestTickPrice;         // To be used for getting recent/latest price quotes
MqlRates mBarPriceInfo[];      // To be used to store the prices, volumes and spread of each bar

double priceClose; // Variable to store the close value of a bar

// Adjust for 5 or 3 digit price currency pairs (as oppposed to the typical 4 digit)
void adjustDigitsForBroker() {
   stopLoss = StopLoss;
   takeProfit = TakeProfit;
   
   // _Digits, Digits() returns the number of decimal digits used to quote the current chart symbol
   if(_Digits == 5 || _Digits == 3){
      stopLoss = stopLoss * 10;
      takeProfit = takeProfit * 10;
   }
}

bool CheckStopLossAndTakeprofit(ENUM_ORDER_TYPE type, double bidOrAskPrice, double SL, double TP) {
   //--- get the SYMBOL_TRADE_STOPS_LEVEL level
   int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   /*
   if(stops_level != 0) {
      PrintFormat("Info: SYMBOL_TRADE_STOPS_LEVEL = %d. StopLoss and TakeProfit must" +
               " not be nearer than %d points from the closing price", stops_level, stops_level);
   }
   */
     
   bool SL_check = false, TP_check = false;
   
   //--- check only two order types
   switch(type) {
      //--- Buy operation
      case  ORDER_TYPE_BUY: {
         if (SetStopLoss) {
            //--- check the StopLoss
            SL_check = (bidOrAskPrice - SL > stops_level * _Point);
            if(!SL_check) {
               PrintFormat("For BUY order, StopLoss=%.5f must be less than %.5f"+
                           " (Bid=%.5f - SYMBOL_TRADE_STOPS_LEVEL=%d points)",
                           EnumToString(type), SL, bidOrAskPrice - stops_level * _Point, bidOrAskPrice, stops_level);
            }
         } else {
            SL_check = true;
         }
         
         if (SetTakeProfit) {
            //--- check the TakeProfit
            TP_check=(TP - bidOrAskPrice > stops_level * _Point);
            if(!TP_check) {
               PrintFormat("For BUY order, TakeProfit=%.5f must be greater than %.5f"+
                           " (Bid=%.5f + SYMBOL_TRADE_STOPS_LEVEL=%d points)",
                           TP, bidOrAskPrice + stops_level * _Point, bidOrAskPrice, stops_level);
            }
         } else {
            TP_check = true;
         }
         
         //--- return the result of checking
         return(SL_check && TP_check);
      }
      //--- Sell operation
      case  ORDER_TYPE_SELL:  {
         if (SetStopLoss) {
            //--- check the StopLoss
            SL_check=(SL - bidOrAskPrice > stops_level * _Point);
            if(!SL_check) {
               PrintFormat("For SELL order, StopLoss=%.5f must be greater than %.5f "+
                           " (Ask=%.5f + SYMBOL_TRADE_STOPS_LEVEL=%d points)",
                           EnumToString(type), SL, bidOrAskPrice + stops_level * _Point, bidOrAskPrice, stops_level);
            }
         } else {
            SL_check = true;
         }
         
         if (SetTakeProfit) {
            //--- check the TakeProfit
            TP_check=(bidOrAskPrice - TP > stops_level * _Point);
            if(!TP_check) {
               PrintFormat("For SELL order, TakeProfit=%.5f must be less than %.5f "+
                           " (Ask=%.5f - SYMBOL_TRADE_STOPS_LEVEL=%d points)",
                           EnumToString(type), TP, bidOrAskPrice - stops_level * _Point, bidOrAskPrice, stops_level);
            }
         } else {
            TP_check = true;
         }
         
         //--- return the result of checking
         return(TP_check && SL_check);
      }
      
      break;
   }
     
   //--- a slightly different function is required for pending orders
   return false;
}