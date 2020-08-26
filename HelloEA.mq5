//+-------------------------------------------------------------------+
//|                                                      HelloEA.mq5  |
//| GitHub: https://github.com/himeshramjee/MT5-Automation/tree/master|
//+-------------------------------------------------------------------+

// #property indicator_separate_window

enum ENUM_HELLOEA_STRATEGIES {
   EMA_ADX_MA_TRENDS = 0,     // S1: Simple Trending using EMA and ADX
   RSI_OBOS = 1,              // S2: RSI, OBOS, Shorts only
   RSI_SPIKES = 2,            // S3: RSI, Spikes, Shorts only
   STOCH_ICHI = 3,            // S4: Silent Stoch and Ichimoku
   PRICE_ACTIONS = 4          // S5: Price Actions
};

input group "Hello EA options";
input ENUM_HELLOEA_STRATEGIES selectedEAStrategy = ENUM_HELLOEA_STRATEGIES::PRICE_ACTIONS;   // Selected Strategy

#include <Controls/Button.mqh>

#include <EAUtils/EAUtils.mqh>
#include <EAUtils/MarketUtils.mqh>
#include <EAUtils/TradeUtils.mqh>

// #include <EAUtils/TrendingStrategy.mqh>
// #include <EAUtils/RSIOBOSStrategy.mqh>
// #include <EAUtils/RSISpikeStrategy.mqh>
// #include <EAUtils/StochimokuStrategy.mqh>
#include <EAUtils/PriceActionsStrategy.mqh>

const int      accountLeverage = (int) AccountInfoInteger(ACCOUNT_LEVERAGE);
const string   accountCurrency = AccountInfoString(ACCOUNT_CURRENCY);
const double   accountStartBalance = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE), 2);

bool tradingEnabled = true;  // True to enable bot trading, false to only signal

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   if (!initMarketUtils() || !initEAUtils() || !initTradeUtils()) {
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

   //--- create timer
   EventSetTimer(60);

   if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::EMA_ADX_MA_TRENDS) {
      /*if(!initTrendingIndicators()) {
         return INIT_FAILED;
      }*/
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::RSI_OBOS) {
      /*if(!initRSIOBOSIndicators()) {
         return INIT_FAILED;
      }*/
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::RSI_SPIKES) {
      /*if(!initRSISpikeIndicators()) {
         return INIT_FAILED;
      }*/
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::STOCH_ICHI) {
      /*if (!initStochimokuIndicators()) {
         return INIT_FAILED;
      }*/
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::PRICE_ACTIONS) {
      if (!initPriceActionsIndicators()) {
         return INIT_FAILED;
      }
   } else {
      Print("No valid trading strategy is defined. HelloEA cannot start.");
      return INIT_FAILED;
   }
   
   Print("Hello EA has successfully initialized. Running...");
   
   if (!isTraderReady()) {
      ExpertRemove();
   }
   
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
      // releaseTrendingIndicators();
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::RSI_OBOS) {
      // releaseRSIOBOSIndicators();
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::RSI_SPIKES) {
      // releaseRSISpikeIndicators();
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::STOCH_ICHI) {
      // releaseStochimokuIndicators();
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::PRICE_ACTIONS) {
      releasePriceActionsIndicators();
   }

   // FIXME: Unfortunately this makes analysing results much harder. 
   // Need to confirm that EA Exit/Remove processing will clean these up properly. Smoke/sniff tests look okish...normal non-test terminal exits show small amount of memory leakage that I've not tracked down yet.
   // At least make this user driven with a chart button.
   // deInitEAUtils();
   
   deInitMarketUtils();
   
   // Print stats
   printExitSummary();
   
   Print("Hello EA is stopped.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
// Called each time a new tick/price quote is received
void OnTick() {
   if (!checkBarCount()) {
      return;
   }
   
   /*
   if (!isNewBar()) {
      // FIXME: This matters on the higher timeframes like M15 even where profitable positions can swing into loss before the candle closes
      return;
   }
   */
   
   if (!handleMarketTickEvent()) {
      ExpertRemove();
      return;
   }
   
   closePositionsAboveLossLimit();
   
   calculateMaxUsedMargin();  
   
   if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::EMA_ADX_MA_TRENDS) {
      /*if (runTrendingStrategy()) {
         sendOrder(false);
      }*/ 
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::RSI_OBOS) {
      /*if (runRSIOBOSStrategy()) {
         sendOrder(false);
      }*/
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::RSI_SPIKES) {
      /*if (runRSISpikeStrategy()) {
         sendOrder(false);
      }*/ 
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::STOCH_ICHI) {
      /*if (runStochimokuStrategy()) {
         sendOrder(false);
      }*/ 
   } else if (selectedEAStrategy == ENUM_HELLOEA_STRATEGIES::PRICE_ACTIONS) {
      if (runPriceActionsStrategy()) {
         sendOrder(false);
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
   Print("HelloEA trades are ", (tradingEnabled ? "Enabled." : "Disabled."));
   
   return true;
}

void printExitSummary(){
   /*
   string                     accountName = AccountInfoString(ACCOUNT_NAME);

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
   */
   
   double accountBalance = NormalizeDouble(AccountInfoDouble(ACCOUNT_BALANCE), 2);
   int totalDays = profitableDaysCounter + lossDaysCounter;
   if (totalDays > 0) {
      PrintFormat("%d days traded. %d profitable, %d hitting profit target, %d ending below profit target and %d ending with losses.", totalDays, profitableDaysCounter, profitableDaysCounter - daysBelowProfitTargetCounter, daysBelowProfitTargetCounter, lossDaysCounter);
      PrintFormat("Average %.2f %s P/L per day. Lowest profit to close a day was %.2f %s. Highest loss to close a day was %.2f %s.", (accountBalance - accountStartBalance) / totalDays, accountCurrency, leastProfitOnADay == 9999999 ? 0 : leastProfitOnADay, accountCurrency, highestLossOnADay == -9999999 ? 0 : highestLossOnADay, accountCurrency);
   }
   PrintFormat("A total of %d orders failed to be placed. A total of %d Sell orders and %d Buy orders were placed.", totalFailedOrderCount, totalSellOrderCount, totalBuyOrderCount);
   
   if (fixedLossLimit <= 0) {
      PrintFormat("Closed %d positions that were above loss limit threshold of %.2f%% of Account Equity per trade. There are currently %d open positions.", lossLimitPositionsClosedCount, percentageLossLimit, PositionsTotal());
   } else {
      PrintFormat("Closed %d positions that were above loss limit value of %.2f %s. There are currently %d open positions.", lossLimitPositionsClosedCount, fixedLossLimit, accountCurrency, PositionsTotal());
   }
   PrintFormat("Max used margin was %f %s. Max floating loss was %f %s. Orders missed due to insufficient margin was %d.", maxUsedMargin, accountCurrency, maxFloatingLoss, accountCurrency, insufficientMarginCount);
}