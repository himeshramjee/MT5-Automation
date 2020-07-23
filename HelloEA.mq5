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

// #property indicator_separate_window

enum ENUM_HELLOEA_STRATEGIES {
   EMA_ADX_MA_TRENDS = 0,     // S1: Simple Trending using EMA and ADX
   RSI_OBOS = 1,              // S2: RSI, OBOS, Shorts only
   RSI_SPIKES = 2,            // S3: RSI, Spikes, Shorts only
   STOCH_ICHI = 3             // S4: Silent Stoch and Ichimoku
};

input group "Hello EA options";
input ENUM_HELLOEA_STRATEGIES selectedEAStrategy = ENUM_HELLOEA_STRATEGIES::STOCH_ICHI;   // Selected Strategy
input ENUM_TIMEFRAMES chartTimeframe = PERIOD_M1;                                         // Select a chart timeframe

#include <Controls/Button.mqh>

#include <EAUtils/EAUtils.mqh>
#include <EAUtils/MarketUtils.mqh>
#include <EAUtils/TradeUtils.mqh>

#include <EAUtils/TrendingStrategy.mqh>
#include <EAUtils/RSIOBOSStrategy.mqh>
#include <EAUtils/RSISpikeStrategy.mqh>
#include <EAUtils/StochimokuStrategy.mqh>

int      accountLeverage = (int) AccountInfoInteger(ACCOUNT_LEVERAGE);
string   accountCurrency = AccountInfoString(ACCOUNT_CURRENCY);
double   accountMarginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

bool enableEATrading = true;  // True to enable bot trading, false to only signal
bool eaInitCompleted = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   isTraderReady();

   if (!initEAUtils()) {
      return INIT_FAILED;
   }
   
   if (!createEAButtons()) {
      return INIT_FAILED;
   }

   if (!validateTradingPermissions()) {
      return INIT_FAILED;
   }

   string message;
   if(!validateOrderVolume(message)) {
      Alert(message);
      return INIT_FAILED;
   }

   if (!initMarketUtils()) {
      return INIT_FAILED;
   }

   //--- create timer
   EventSetTimer(60);

   if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::EMA_ADX_MA_TRENDS) {
      if(!initTrendingIndicators()) {
         return INIT_FAILED;
      }
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::RSI_OBOS) {
      if(!initRSIOBOSIndicators()) {
         return INIT_FAILED;
      }
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::RSI_SPIKES) {
      if(!initRSISpikeIndicators()) {
         return INIT_FAILED;
      }
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::STOCH_ICHI) {
      if (!initStochimokuIndicators()) {
         return INIT_FAILED;
      }
   } else {
      Print("No valid trading strategy is defined. HelloEA cannot start.");
      return INIT_FAILED;
   }
   
   Print("Hello EA has successfully initialized. Running...");
   eaInitCompleted = true;
   return INIT_SUCCEEDED;
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
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::STOCH_ICHI) {
      releaseStochimokuIndicators();
   }
   
   deInitEAUtils();
   deInitMarketUtils();
   
   // Print stats
   printAccountInfo();
   
   Print("Hello EA is stopped.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
// Called each time a new tick/price quote is received
void OnTick() {
     
   // FIXME: Retest. This may no longer be needed.
   if (!eaInitCompleted) {
      Print("Warning: Skipping tick event as eaInitCompleted is false.");
   }
   
   if (!checkBarCount() || !isNewBar()) {
      return;
   }
   
   if (!handleMarketTickEvent()) {
      ExpertRemove();
      return;
   }
   
   closePositionsAboveLossLimit();
   
   calculateMaxUsedMargin();  
   
   if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::EMA_ADX_MA_TRENDS) {
      if (runTrendingStrategy()) {
         sendOrder();
      }  
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::RSI_OBOS) {
      if (runRSIOBOSStrategy()) {
         sendOrder();
      }  
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::RSI_SPIKES) {
      if (runRSISpikeStrategy()) {
         sendOrder();
      }  
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::STOCH_ICHI) {
      if (runStochimokuStrategy()) {
         sendOrder();
      }  
   } else {
      Print("Hello EA found no valid selected strategy.");
   }   
}

bool isTraderReady() {
   string autoTraderWarningMessage = "Automated trading is risky. Ensure you test this EA with a demo account first. Use good risk management at all times!";
   Print(autoTraderWarningMessage);
   
   if (MQLInfoInteger(MQL_TESTER) != 1 && MQLInfoInteger(MQL_VISUAL_MODE) != 1) {
      int answer = MessageBox(autoTraderWarningMessage, "Warning: Automated trading could blow your account", MB_OK);
      if(answer != IDOK) {
         return false;
      }
   }

   Print("Welcome to Hello EA!");
   Print("Selected chart timeframe is ", chartTimeframe);
   Print("HelloEA trades are ", (enableEATrading ? "Enabled." : "Disabled."));
   
   return true;
}

void printAccountInfo(){
   string                     accountName = AccountInfoString(ACCOUNT_NAME);

   double                     accountInitialBalance = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE), 2);
   double                     accountFloatingProftLoss = NormalizeDouble(AccountInfoDouble(ACCOUNT_PROFIT), 2);
   double                     accountInitialEquity = NormalizeDouble(AccountInfoDouble(ACCOUNT_EQUITY), 2);
   double                     accountFreeMargin = NormalizeDouble(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2);
   double                     accountMarginInitial = NormalizeDouble(AccountInfoDouble(ACCOUNT_MARGIN_INITIAL), 2);
   double                     accountMarginMaintenance = NormalizeDouble(AccountInfoDouble(ACCOUNT_MARGIN_MAINTENANCE), 2);
   
   ENUM_ACCOUNT_STOPOUT_MODE  accountMarginSOMode = (ENUM_ACCOUNT_STOPOUT_MODE) AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE);
   double                     accountMarginSOCall = AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL);
   double                     accountMarginSOSO = AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);
   
   string                     accountInfoMessage = StringFormat("Active account is %s. Account leverage: %f. Currency: %s. Balance: %f. Floating P/L: %f. Equity: %f. Free Margin: %f. Initial Margin: %f. Margin Maintenance: %f.", accountName, accountLeverage, accountCurrency, accountInitialBalance, accountFloatingProftLoss, accountInitialEquity, accountFreeMargin, accountMarginInitial, accountMarginMaintenance);
   string                     marginInfoMessage = StringFormat("Brokers Margin call settings for account: SO Mode: %s. Level: %f%. SO Call: %f. SO SO: %f.", EnumToString(accountMarginSOMode), accountMarginLevel, accountMarginSOCall, accountMarginSOSO);
   
   Print(accountInfoMessage);
   Print(marginInfoMessage);
   PrintFormat("Max used margin was %f %s. Max floating loss was %f %s. Orders missed due to insufficient margin was %d.", maxUsedMargin, accountCurrency, maxFloatingLoss, accountCurrency, insufficientMarginCount);
   PrintFormat("Closed %d positions that were above loss limit value of %f %s. There are currently %d open positions.", lossLimitPositionsClosedCount, lossLimitInCurrency, accountCurrency, PositionsTotal());
}