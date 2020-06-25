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
//| https://www.mql5.com/en/docs/constants/tradingconstants/enum_trade_request_actions
//| https://www.mql5.com/en/forum/192909#comment_5070465
//| https://www.mql5.com/en/docs/objects/objectcreate
//| https://www.mql5.com/en/docs/event_handlers/ontick
//+------------------------------------------------------------------+

// TODOs:
// 0. Ongoing - Iterate on strategy back testing and improvements.
// 1. Done - At the least see if we can split methods out into separate files.
// 2. Find a linter.
// 3. Done - Implement RSI strategy.
// 4. Rewrite Stop Loss and Take Profit calculations. Ball ache of note due to different broker and asset types.
// 5. Done - Let user activate 1 or more strategies. Update: Decided on single strategy at a time.
// 6. Not a single try/catch?!
// 7. Add input validations to user inputs and methods. 
// 8. Optimizations. e.g. Test use of uchar and other.
// 9. Prototype done, research class design and make this a real thing

#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

enum ENUM_HELLOEA_STRATEGIES {
   EMA_ADX_MA_TRENDS = 0,     // S1: Simple Trending using EMA and ADX
   RSI_OBOS = 1,              // S2: RSI, OBOS, Shorts only
   RSI_SPIKES = 2             // S3: RSI, Spikes, Shorts only
};

input group "Hello EA Options";
input ENUM_HELLOEA_STRATEGIES selectedEAStrategy = RSI_OBOS;   // Selected Strategy
input ENUM_TIMEFRAMES chartTimeFrame = PERIOD_M1;              // Select a chart timeframe

bool enableEATrading = true;                                  // True to enable bot trading, false to only signal

#include <Controls/Button.mqh>

#include <EAUtils/EAUtils.mqh>
#include <EAUtils/TradeUtils.mqh>
// #include <EAUtils/PriceUtils.mqh>
#include <EAUtils/TrendingStrategy.mqh>
#include <EAUtils/RSIOBOSStrategy.mqh>
#include <EAUtils/RSISpikeStrategy.mqh>

CButton eaStartStopButton;

string accountName = AccountInfoString(ACCOUNT_NAME);
string accountCurrency = AccountInfoString(ACCOUNT_CURRENCY);
int accountLeverage = (int) AccountInfoInteger(ACCOUNT_LEVERAGE);

double accountInitialBalance = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE), 2);
double accountFloatingProftLoss = NormalizeDouble(AccountInfoDouble(ACCOUNT_PROFIT), 2);
double accountInitialEquity = NormalizeDouble(AccountInfoDouble(ACCOUNT_EQUITY), 2);
double accountFreeMargin = NormalizeDouble(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2);

ENUM_ACCOUNT_STOPOUT_MODE accountMarginSOMode = (ENUM_ACCOUNT_STOPOUT_MODE) AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE);
double accountMarginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
double accountMarginSOCall = AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL);
double accountMarginSOSO = AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);

string accountInfoMessage = StringFormat("Active account is %s. Account leverage is %f and currency is %s. Balance is %f, Floating P/L is %f, Equity is %f and Free Margin is %f.", accountName, accountLeverage, accountCurrency, accountInitialBalance, accountFloatingProftLoss, accountInitialEquity, accountFreeMargin);
string marginInfoMessage = StringFormat("Brokers Margin call settings for account: SO Mode: %s. Level: %f%. SO Call: %f. SO SO: %f.", EnumToString(accountMarginSOMode), accountMarginLevel, accountMarginSOCall, accountMarginSOSO);

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   Print("Welcome to Hello EA!");
   Print("Selected chart timeframe is ", chartTimeFrame);
   Print("HelloEA trades are ", (enableEATrading ? "Enabled." : "Disabled."));
   
   if (!createEAStartStopButton()) {
      return(INIT_FAILED);
   }
   
   Print(accountInfoMessage);
   Print(marginInfoMessage);

   if (!validateTradingPermissions()) {
      return(INIT_FAILED);
   }

   string message;
   if(!validateOrderVolume(lot, message)) {
      Alert(StringFormat("Configured lot size (%.2f) isn't within Symbol Specification.", lot));
      Alert(message);
      return(INIT_FAILED);
   }

   //--- create timer
   EventSetTimer(60);
   
   if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::EMA_ADX_MA_TRENDS) {
      if(!initTrendingIndicators()) {
         return(INIT_FAILED);
      }
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::RSI_OBOS) {
      if(!initRSIOBOSIndicators()) {
         return(INIT_FAILED);
      }
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::RSI_SPIKES) {
      if(!initRSISpikeIndicators()) {
         return(INIT_FAILED);
      }
   } else {
      Print("No valid trading strategy is defined. HelloEA cannot start.");
      return(INIT_FAILED);
   }
   
   if (!checkBarCount()) {
      return(INIT_FAILED);
   }
   
   Print("Hello EA has successfully initialized. Running...");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   Print("Hello EA is shutting down...");
   
   //--- destroy timer
   EventKillTimer();
   
   if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::EMA_ADX_MA_TRENDS) {
      releaseTrendingIndicators();
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::RSI_OBOS) {
      releaseRSIOBOSIndicators();
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::RSI_SPIKES) {
      releaseRSISpikeIndicators();
   }
   
   // Print stats
   Print("Printing stats for this run before exiting...");
   PrintFormat("Max used margin was %f %s. Max floating loss was %f %s. Orders missed due to insufficient margin was %d.", maxUsedMargin, accountCurrency, maxFloatingLoss, accountCurrency, insufficientMarginCount);
   PrintFormat("Closed %d positions that were above loss limit value of %f %s. There are currently %d open positions.", lossLimitPositionsClosedCount, lossLimitInCurrency, accountCurrency, PositionsTotal());
   Print("Reprinting start up stats...");
   Print(accountInfoMessage);
   Print(marginInfoMessage);
   Print("Hello EA is stopped.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
// Called each time a new tick/price quote is received
void OnTick() {
   if (!checkBarCount() || !isNewBar()) {
      return;
   }
   
   if (!setTickPricing()) {
      return;
   }
   
   closePositionsAboveLossLimit();
   
   calculateMaxUsedMargin();  
   
   if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::EMA_ADX_MA_TRENDS) {
      runTrendingStrategy();
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::RSI_OBOS) {
      runRSIOBOSStrategy();
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::RSI_SPIKES) {
      runRSISpikesStrategy();
   } else {
      Print("Hello EA found no valid selected strategy.");
   }
}

void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam) {
   if (id == CHARTEVENT_OBJECT_CLICK) {
      // PrintFormat("You clicked on chart. lparam/x-coordinate is %d. dparam/y-coordinate is %f. sparam/object-name is %s.", lparam, dparam, sparam);
      // Comment(StringFormat("You clicked on chart. lparam/x-coordinate is %d. dparam/y-coordinate is %f. sparam/no-clue-yet is %s.", lparam, dparam, sparam));
      
      if (sparam == "eaStartStopButton") {
         eaStartStopButtonHandler();     
      }
   }
}