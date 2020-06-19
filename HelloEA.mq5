//+------------------------------------------------------------------+
//|                                                      HelloEA.mq5 |
//| GitHub: https://github.com/himeshramjee/MT5-Automation/tree/master
//| Code based on following guides:
//| https://www.mql5.com/en/articles/100
//| https://www.mql5.com/en/articles/2555
//| https://www.mql5.com/en/docs/constants/errorswarnings/errorcodes
//| https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants
//| https://www.mql5.com/en/docs/convert/stringformat
//| https://www.mql5.com/en/forum/137301#comment_3474196
//| https://www.mql5.com/en/articles/2555
//| https://www.mql5.com/en/docs/constants/tradingconstants/enum_trade_request_actions
//+------------------------------------------------------------------+

// TODOs:
// 1. At the least see if we can split methods out into separate files.
// 2. Find a linter.
// 3. Implement RSI strategy.
// 4. Rewrite Stop Loss and Take Profit calculations. Ball ache of note due to different broker and asset types.
// 5. Let user activate 1 or more strategies.
// 6. Not a single try/catch?!
// 7. Test use of uchar and other optimizations

#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <EAUtils/EAUtils.mqh>
// #include <EAUtils/TrendingStrategy.mqh>
#include <EAUtils/RSIStrategy.mqh>
#include <EAUtils/PriceUtils.mqh>
#include <EAUtils/TradeUtils.mqh>

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   if (!validateTradingPermissions()) {
      return(INIT_FAILED);
   }

   string message;
   if(!validateOrderVolume(Lot, message)) {
      Alert(StringFormat("Configured lot size (%.2f) isn't withing Symbol Specification.", Lot));
      Alert(message);
   }

   //--- create timer
   EventSetTimer(60);
   
   /*
   if(!initTrendingIndicators()) {
      return(INIT_FAILED);
   }
   */

   if(!initRSIIndicators()) {
      return(INIT_FAILED);
   }
   
   //--- Adjust for 5 or 3 digit price currency pairs (as oppposed to the typical 4 digit)
   // _Digits, Digits() returns the number of decimal digits used to quote the current chart symbol
   stopLoss = StopLoss;
   takeProfit = TakeProfit;
   adjustDigitsForBroker();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   //--- destroy timer
   EventKillTimer();
   
   // releaseTrendingIndicators();
   releaseRSIIndicators();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
// Called each time a new tick/price quote is received
void OnTick() {
   if (!checkBarCount() || !isNewBar()) {
      return;
   }

   // Check state of open positions. Returns true if new positions can be opened, else false. 
   if (!checkOpenPositions()) {
      return;
   }
   
   // runTrendingStrategy();
   runRSIStrategy();
}