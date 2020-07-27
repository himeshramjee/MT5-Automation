input group "S4: Strategy 4 - Stoch & Ichimoku"
input bool              s4EnablePushNotification = false;   // Enable signal push notifications
input double            s4MinimumTakeProfitValue = 5.0;     // Value (in currency) at which to Take Profit
input bool              s4TradeCrash = true;                // True to trade Crash, False to trade Boom

// Stoch Indicator
ENUM_TIMEFRAMES   s4StoChartTimeframe = PERIOD_M1;  // Chart timeframe to generate Stochastic data
int               s4StoKPeriod = 1;                 // the K period (the number of bars for calculation)
int               s4StoDPeriod = 1;                 // the D period (the period of primary smoothing)
int               s4StoSlowing = 1;                 // period of final smoothing      

double                  s4StoMainBuffer[];
double                  s4StoSignalBuffer[];
int                     s4StochasticHandle;
int                     s4StoBarCount = 30;

// Ichimoku Indicator
ENUM_TIMEFRAMES   s4IchChartTimeframe = PERIOD_M1;    // Chart timeframe to generate Ichimoku data
int               s4IchTenkanSan = 9;                // Averaging period for Tekan-san
int               s4IchKijunSen = 9;                 // Averaging period for Kijun-sen
int               s4IchSenkouSpanB = 52;             // Averaging period forSenkou Span B

int                     s4IchimokuHandle;
double                  s4IchTenkanSanBuffer[];
double                  s4IchKijunSenBuffer[];
double                  s4IchSenkouSpanABuffer[];
double                  s4IchSenkouSpanBBuffer[];
double                  s4IchChinkouSpanBuffer[];
int                     s4IchBarCount = 30;

bool initStochimokuIndicators() {
   s4StochasticHandle = iStochastic(_Symbol, s4StoChartTimeframe, s4StoKPeriod, s4StoDPeriod, s4StoSlowing, MODE_SMA, STO_LOWHIGH);
   
   if (s4StochasticHandle < 0) {
      Alert("Error Creating Handle for Stochastic indicator - error: ", GetLastError(), "!!");
      return false;
   }
   
   s4IchimokuHandle = iIchimoku(_Symbol, s4IchChartTimeframe, s4IchTenkanSan, s4IchKijunSen, s4IchSenkouSpanB);
   
   if (s4IchimokuHandle < 0) {
      Alert("Error Creating Handle for Ichimoku indicator - error: ", GetLastError(), "!!");
      return false;
   }
   
   int subWindow = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   if (subWindow == 0) {
      // 0 is the main window meaning there are no indicator windows currently loaded so load one
      subWindow = 1;
      
      if(!ChartIndicatorAdd(0, subWindow, s4StochasticHandle)) {
         PrintFormat("Failed to add Stochastic indicator on %d chart window. Error code  %d", subWindow,GetLastError());
      }
      if(!ChartIndicatorAdd(0, subWindow, s4IchimokuHandle)) {
         PrintFormat("Failed to add Ichimoku indicator on %d chart window. Error code  %d", subWindow,GetLastError());
      }
   }
   
   // Ensure indexing of arrays is in timeseries format, i.e. 0 = current unfinished candle to n = oldest candle
   ArraySetAsSeries(s4StoMainBuffer, true);
   ArraySetAsSeries(s4StoSignalBuffer, true);
   
   return true;
}


void releaseStochimokuIndicators() {
   IndicatorRelease(s4StochasticHandle);
   IndicatorRelease(s4IchimokuHandle);
}

bool populateS4Prices() {
   // Get the Stochastic data
   //--- fill a part of the StochasticBuffer array with values from the indicator buffer that has 0 index
   if (CopyBuffer(s4StochasticHandle, MAIN_LINE /* 0 */, 0, s4StoBarCount, s4StoMainBuffer) < 0) {
      //--- if the copying fails, tell the error code
      PrintFormat("1. Failed to copy data from the iStochastic indicator, error code %d", GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated
      return(false);
   }
   
   //--- fill a part of the SignalBuffer array with values from the indicator buffer that has index 1
   if (CopyBuffer(s4StochasticHandle, SIGNAL_LINE /* 1 */, 0, s4StoBarCount, s4StoSignalBuffer) < 0) {
      //--- if the copying fails, tell the error code
      PrintFormat("2. Failed to copy data from the iStochastic indicator, error code %d", GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated
      return(false);
   }
   
   // Get Ichimoku data
   //--- fill a part of the Tenkan_sen_Buffer array with values from the indicator buffer that has 0 index
   if(CopyBuffer(s4IchimokuHandle, 0, 0, s4IchBarCount, s4IchTenkanSanBuffer) < 0) {
      //--- if the copying fails, tell the error code
      PrintFormat("1.Failed to copy data from the iIchimoku indicator, error code %d", GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated
      return(false);
   }
   
   //--- fill a part of the Kijun_sen_Buffer array with values from the indicator buffer that has index 1
   if(CopyBuffer(s4IchimokuHandle, 1, 0, s4IchBarCount, s4IchKijunSenBuffer) < 0) {
      //--- if the copying fails, tell the error code
      PrintFormat("2.Failed to copy data from the iIchimoku indicator, error code %d", GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated
      return(false);
   }
 
   //--- fill a part of the Chinkou_Span_Buffer array with values from the indicator buffer that has index 2
   //--- if senkou_span_shift>0, the line is shifted in the future direction by senkou_span_shift bars
   if(CopyBuffer(s4IchimokuHandle, 2, 0, s4IchBarCount, s4IchChinkouSpanBuffer) < 0) {
      //--- if the copying fails, tell the error code
      PrintFormat("3.Failed to copy data from the iIchimoku indicator, error code %d", GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated
      return(false);
   }
 
   //--- fill a part of the Senkou_Span_A_Buffer array with values from the indicator buffer that has index 3
   //--- if senkou_span_shift>0, the line is shifted in the future direction by senkou_span_shift bars
   if(CopyBuffer(s4IchimokuHandle, 3, 0, s4IchBarCount, s4IchSenkouSpanABuffer) < 0) {
      //--- if the copying fails, tell the error code
      PrintFormat("4.Failed to copy data from the iIchimoku indicator, error code %d", GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated
      return(false);
   }
 
   //--- fill a part of the Senkou_Span_B_Buffer array with values from the indicator buffer that has 4 index
   //--- when copying Chinkou Span, we don't need to consider the shift, since the Chinkou Span data
   //--- is already stored with a shift in iIchimoku  
   if(CopyBuffer(s4IchimokuHandle, 4, 0, s4IchBarCount, s4IchSenkouSpanBBuffer) < 0) {
      //--- if the copying fails, tell the error code
      PrintFormat("5.Failed to copy data from the iIchimoku indicator, error code %d", GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated
      return(false);
   }
   
   return true;

}

bool runStochimokuSellStrategy() {
   static bool s4SellCondition1SignalOn;
   static datetime s4SellCondition1TimeAtSignal;
   static double s4SellConditionPriceAtSignal;
   
   // PrintFormat("Checking conditions: Signal is currently %s and active conditions count is %d.", (string)s4SellCondition1SignalOn, bearishPatternsFoundCounter);
   if (bearishPatternsFoundCounter == 0 || !isBearishMarket()) {
      return false;
   }
   
   if (!s4SellCondition1SignalOn && bearishPatternsFoundCounter > 0) { // && s4StoSignalBuffer[0] >= 80) { // && s4IchKijunSenBuffer[0] >= 80) {
      // string message = StringFormat("s4StoMainBuffer[0] = %f, s4StoSignalBuffer[0] = %f, s4IchTenkanSanBuffer[0] = %f, s4IchKijunSenBuffer[0] = %f, s4IchChinkouSpanBuffer[0] = %f, s4IchSenkouSpanABuffer[0] = %f, s4IchSenkouSpanBBuffer[0] = %f.", s4StoMainBuffer[0], s4StoSignalBuffer[0], s4IchTenkanSanBuffer[0], s4IchKijunSenBuffer[0], s4IchChinkouSpanBuffer[0], s4IchSenkouSpanABuffer[0], s4IchSenkouSpanBBuffer[0]);
      // Print(message);;

      s4SellCondition1SignalOn = true;
      s4SellCondition1TimeAtSignal = TimeCurrent();
      s4SellConditionPriceAtSignal = latestTickPrice.bid;
      
      // Add a visual cue
      string visualCueName = StringFormat("S4 signal at %s. BearishPattern count: %d.", (string)s4SellCondition1TimeAtSignal, bearishPatternsFoundCounter);
      ObjectCreate(0, visualCueName, OBJ_ARROW_DOWN, 0, s4SellCondition1TimeAtSignal, latestTickPrice.bid + (50 * Point()));
      ObjectSetInteger(0, visualCueName, OBJPROP_ANCHOR, ANCHOR_TOP);
      ObjectSetInteger(0, visualCueName, OBJPROP_ALIGN, ALIGN_CENTER);
      ObjectSetInteger(0, visualCueName, OBJPROP_FILL, true);
      ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
      registerChartObject(visualCueName);
   }
   
   if(s4SellCondition1SignalOn) {      
      setupGenericTradeRequest();
      mTradeRequest.type = ORDER_TYPE_SELL;                                         // Sell Order
      mTradeRequest.price = NormalizeDouble(latestTickPrice.bid, _Digits);           // latest Bid price
      mTradeRequest.comment = mTradeRequest.comment + "S4 Sell conditions.";
      
      // Reset signal as all conditions have triggered and order can be placed
      s4SellCondition1SignalOn = false;
      
      return true;
   }
   
   return false;
}

bool runStochimokuBuyStrategy() {
   return false;
   
   static bool s4BuyCondition1SignalOn;
   static datetime s4BuyCondition1TimeAtSignal;
   static double s4BuyConditionPriceAtSignal;
   
   if (bullishPatternsFoundCounter == 0 || !isBullishMarket()) {
      return false;
   }
      
   if (!s4BuyCondition1SignalOn && (s4StoSignalBuffer[0] <= 20)) { // && s4IchKijunSenBuffer[0] <= 20) {
      s4BuyCondition1SignalOn = true;
      s4BuyCondition1TimeAtSignal = TimeCurrent();
      s4BuyConditionPriceAtSignal = latestTickPrice.ask;
      
      // Add a visual cue
      string visualCueName = StringFormat("S4 signalled at %s. StochSignal: %f. Ask price: %f.", (string)s4BuyCondition1TimeAtSignal, s4StoSignalBuffer[0], latestTickPrice.ask);
      ObjectCreate(0, visualCueName, OBJ_ARROW_UP, 0, s4BuyCondition1TimeAtSignal, latestTickPrice.ask + (20 * Point()));
      ObjectSetInteger(0, visualCueName, OBJPROP_ANCHOR, ANCHOR_TOP);
      ObjectSetInteger(0, visualCueName, OBJPROP_ALIGN, ALIGN_CENTER);
      ObjectSetInteger(0, visualCueName, OBJPROP_FILL, true);
      ObjectSetInteger(0, visualCueName, OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(0, visualCueName, OBJPROP_SELECTABLE, 1);
      registerChartObject(visualCueName);
      
      // Signal triggered, now wait x mins before opening the Sell position      
      return false;
   }
   
   if(s4BuyCondition1SignalOn) {      
      setupGenericTradeRequest();
      mTradeRequest.type = ORDER_TYPE_BUY;
      mTradeRequest.price = NormalizeDouble(latestTickPrice.ask, _Digits);
      mTradeRequest.comment = mTradeRequest.comment + "S4 Buy conditions.";
      
      // Reset signal as all conditions have triggered and order can be placed
      s4BuyCondition1SignalOn = false;
      
      return true;
   }
   
   return false;
}

void closeS4ITMPositions() {
   int openPositionCount = PositionsTotal(); // number of open positions
   
   for (int i = 0; i < openPositionCount; i++) {
      ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE) PositionGetInteger(POSITION_TYPE);

      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetSymbol(i);
      double profitLoss = PositionGetDouble(POSITION_PROFIT);
      ulong  magic = PositionGetInteger(POSITION_MAGIC);
      double volume = PositionGetDouble(POSITION_VOLUME);
      
      // Only act on positions opened by this EA
      if (magic == EAMagic) {
         if (positionType == POSITION_TYPE_SELL) {
            if(profitLoss >= s4MinimumTakeProfitValue) {
               PrintFormat("Close profitable position - %s, Ticket: %d. Symbol: %s. Profit/Loss: %f.", EnumToString(positionType), ticket, symbol, profitLoss);
               
               closePosition(magic, ticket, symbol, positionType, volume, "S4 profit conditions.", true);
            } else {
               // wait bit longer
               return;
            }
         }
      }
   }
}

bool runStochimokuStrategy() {
   if (!populateS4Prices()) {
      return false;
   }

   closeS4ITMPositions();
      
   if (openPositionLimitReached()){
      return false;
   }

   if (s4TradeCrash) {
      return runStochimokuSellStrategy();
   } else {
      return runStochimokuBuyStrategy();
   }
}