//+------------------------------------------------------------------+
//|                                                   PriceUtils.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

input group "Pricing";
bool setStopLoss = false; // Automatically set Stop Loss
bool setTakeProfit = false; // Automatically set Take Profit

bool validateStopLossAndTakeprofit(ENUM_ORDER_TYPE type, double bidOrAskPrice, double SL, double TP) {
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
         if (setStopLoss) {
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
         
         if (setTakeProfit) {
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
         if (setStopLoss) {
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
         
         if (setTakeProfit) {
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