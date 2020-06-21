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
// 0. Ongoing - Iterate on strategy back testing and improvements.
// 1. Done - At the least see if we can split methods out into separate files.
// 2. Find a linter.
// 3. Done - Implement RSI strategy.
// 4. Rewrite Stop Loss and Take Profit calculations. Ball ache of note due to different broker and asset types.
// 5. Done - Let user activate 1 or more strategies. Update: Decided on single strategy at a time.
// 6. Not a single try/catch?!
// 7. Test use of uchar and other optimizations

#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <EAUtils/EAUtils.mqh>
#include <EAUtils/TrendingStrategy.mqh>
#include <EAUtils/RSIStrategy.mqh>
#include <EAUtils/PriceUtils.mqh>
#include <EAUtils/TradeUtils.mqh>

input ENUM_TIMEFRAMES chartTimeframe = PERIOD_M1; // Chart Timeframe

enum ENUM_HELLOEA_STRATEGIES {
   EMA_ADX_Trending = 0,      // S1: Simple Trending using EMA and ADX
   RSI_Sells = 1              // S2: Simple RSI, No Trend, Short only
};
input ENUM_HELLOEA_STRATEGIES selectedEAStrategy = RSI_Sells; // Selected Strategy

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
   
   if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::EMA_ADX_Trending) {
      if(!initTrendingIndicators()) {
         return(INIT_FAILED);
      }
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::RSI_Sells) {
      if(!initRSIIndicators()) {
         return(INIT_FAILED);
      }
   }
   
   //--- Adjust for 5 or 3 digit price currency pairs (as oppposed to the typical 4 digit)
   adjustDigitsForBroker();
   
   Print("Welcome to Hello EA!");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   //--- destroy timer
   EventKillTimer();
   
   if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::EMA_ADX_Trending) {
      releaseTrendingIndicators();
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::RSI_Sells) {
      releaseRSIIndicators();
   }
   
   Print("Hello EA is shutting donwn.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
// Called each time a new tick/price quote is received
void OnTick() {
   if (!checkBarCount() || !isNewBar()) {
      return;
   }
   
   closePositionsAboveLossLimit();
   
   if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::EMA_ADX_Trending) {
      runTrendingStrategy();
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::RSI_Sells) {
      runRSIStrategy();
   }
}