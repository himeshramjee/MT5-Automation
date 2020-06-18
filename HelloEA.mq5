//+------------------------------------------------------------------+
//|                                                      HelloEA.mq5 |
//| Code based on following guides:
//| https://www.mql5.com/en/articles/100
//| https://www.mql5.com/en/articles/2555
//| https://www.mql5.com/en/docs/constants/errorswarnings/errorcodes
//| https://www.mql5.com/en/docs/convert/stringformat
//+------------------------------------------------------------------+

#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

//--- input parameters
// TODO: is uchar more efficient? 
input int      StopLoss=30;   // Stop Loss (Pips)
input int      TakeProfit=100;// Take Profit (Pips)
input int      ADXPeriod=8;   // ADX Period
input int      MAPeriod=8;    // Moving Average Period
input int      EAMagic=10024; // EA Magic Number
input double   AdxMin=22.0;   // Minimum ADX Value
input double   Lot=0.5;       // Lots to Trade

//--- Other parameters
int adxHandle; // handle for our ADX indicator
int maHandle;  // handle for our Moving Average indicator
double plsDI[],minDI[],adxVal[]; // Dynamic arrays to hold the values of +DI, -DI and ADX values for each bars
double maVal[]; // Dynamic array to hold the values of Moving Average for each bars
double priceClose; // Variable to store the close value of a bar
int stopLoss, takeProfit;   // To be used for Stop Loss & Take Profit values

long buyTickets[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   string message;
   
   if(!ValidateOrderVolume(Lot, message)) {
      Alert(StringFormat("Configured lot size (%.2f) isn't withing Symbol Specification.", Lot));
      Alert(message);
   }

   //--- create timer
   EventSetTimer(60);
   
   //--- Get handle for ADX indicator
   // NULL and 0 are the Symbol and Timeframe values respectively and values returned are from the currently active chart
   adxHandle = iADX(NULL, 0, ADXPeriod);
   
   //--- Get the handle for Moving Average indicator
   // _Symbol, symbol() or NULL return the Chart Symbol for the currently active chart
   // _Period, period() or 0 return the Timeframe for the currently active chart
   maHandle = iMA(_Symbol,_Period, MAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   //--- What if handle returns Invalid Handle
   if(adxHandle < 0 || maHandle < 0) {
      Alert("Error Creating Handles for indicators - error: ", GetLastError(), "!!");
   }
   
   //--- Adjust for 5 or 3 digit price currency pairs (as oppposed to the typical 4 digit)
   // _Digits, Digits() returns the number of decimal digits used to quote the current chart symbol
   stopLoss = StopLoss;
   takeProfit = TakeProfit;
   if(_Digits == 5 || _Digits == 3){
      stopLoss = stopLoss * 10;
      takeProfit = takeProfit * 10;
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   //--- destroy timer
   EventKillTimer();
   
   // Release indicator handles
   IndicatorRelease(adxHandle);
   IndicatorRelease(maHandle);   
}

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

bool ValidateFreeMargin(string symb, double lots, ENUM_ORDER_TYPE type) {
   //--- Getting the opening price
   MqlTick mqltick;
   SymbolInfoTick(symb,mqltick);
   double price=mqltick.ask;
   
   if(type==ORDER_TYPE_SELL)
      price=mqltick.bid;
   
   //--- values of the required and free margin
   double margin,free_margin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   
   //--- call of the checking function   
   if(!OrderCalcMargin(type,symb,lots,price,margin)) {
      //--- something went wrong, report and return false
      Print("Error in ",__FUNCTION__," code=",GetLastError());
      
      // FIXME: Method call?
      return(false);
   }
   
   //--- if there are insufficient funds to perform the operation
   if(margin>free_margin) {
      //--- report the error and return false
      Print("Not enough money for ",EnumToString(type)," ",lots," ",symb," Error code=",GetLastError());
      
      // FIXME: Method call?
      return(false);
   }
   
   // FIXME: Method call?
   return(true);
}

// TODO: Note this example uses the pointer reference for description.
bool ValidateOrderVolume(double volume, string &description) {
   //--- minimal allowed volume for trade operations
   double min_volume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   if(volume < min_volume) {
      description = StringFormat("Volume is less than the minimal allowed SYMBOL_VOLUME_MIN=%.2f", min_volume);
      return(false);
   }

   //--- maximal allowed volume of trade operations
   double max_volume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   if(volume > max_volume) {
      description = StringFormat("Volume is greater than the maximal allowed SYMBOL_VOLUME_MAX=%.2f", max_volume);
      return(false);
   }

   //--- get minimal step of volume changing
   double volume_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

   int ratio = (int) MathRound(volume / volume_step);
   if(MathAbs(ratio * volume_step - volume) > 0.0000001) {
      description = StringFormat("Volume is not a multiple of the minimal step SYMBOL_VOLUME_STEP=%.2f, the closest correct volume is %.2f",
                               volume_step,ratio*volume_step);
      return(false);
   }
   
   description = StringFormat("Correct volume value (%.2f)", volume);
   
   return(true);
}

bool CheckStopLossAndTakeprofit(ENUM_ORDER_TYPE type, double bidOrAskPrice, double SL, double TP) {
   //--- get the SYMBOL_TRADE_STOPS_LEVEL level
   int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stops_level != 0) {
      PrintFormat("SYMBOL_TRADE_STOPS_LEVEL = %d. StopLoss and TakeProfit must" +
               " not be nearer than %d points from the closing price", stops_level, stops_level);
   }
     
   bool SL_check = false, TP_check = false;
   
   //--- check only two order types
   switch(type) {
      //--- Buy operation
      case  ORDER_TYPE_BUY: {
         //--- check the StopLoss
         SL_check = (bidOrAskPrice - SL > stops_level * _Point);
         if(!SL_check) {
            PrintFormat("For order %s StopLoss=%.5f must be less than %.5f"+
                        " (Bid=%.5f - SYMBOL_TRADE_STOPS_LEVEL=%d points)",
                        EnumToString(type), SL, bidOrAskPrice - stops_level * _Point, bidOrAskPrice, stops_level);
         }
         
         //--- check the TakeProfit
         TP_check=(TP - bidOrAskPrice > stops_level * _Point);
         if(!TP_check) {
            PrintFormat("For order %s TakeProfit=%.5f must be greater than %.5f"+
                        " (Bid=%.5f + SYMBOL_TRADE_STOPS_LEVEL=%d points)",
                        EnumToString(type), TP, bidOrAskPrice + stops_level * _Point, bidOrAskPrice, stops_level);
         }
         
         //--- return the result of checking
         return(SL_check && TP_check);
      }
      //--- Sell operation
      case  ORDER_TYPE_SELL:  {
         //--- check the StopLoss
         SL_check=(SL - bidOrAskPrice > stops_level * _Point);
         if(!SL_check) {
            PrintFormat("For order %s StopLoss=%.5f must be greater than %.5f "+
                        " (Ask=%.5f + SYMBOL_TRADE_STOPS_LEVEL=%d points)",
                        EnumToString(type), SL, bidOrAskPrice + stops_level * _Point, bidOrAskPrice, stops_level);
         }
         
         //--- check the TakeProfit
         TP_check=(bidOrAskPrice - TP > stops_level * _Point);
         if(!TP_check) {
            PrintFormat("For order %s TakeProfit=%.5f must be less than %.5f "+
                        " (Ask=%.5f - SYMBOL_TRADE_STOPS_LEVEL=%d points)",
                        EnumToString(type), TP, bidOrAskPrice - stops_level * _Point, bidOrAskPrice, stops_level);
         }
         
         //--- return the result of checking
         return(TP_check && SL_check);
      }
      
      break;
   }
     
   //--- a slightly different function is required for pending orders
   return false;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
// Called each time a new tick/price quote is received
void OnTick() {

   // Do we have enough bars to work with
   int barCount = Bars(_Symbol,_Period);
   if(barCount < 60) {
      // TODO: Post to Journal
      Alert("EA will not activate as there are less than 60 bars. Bar count: ", barCount, "."); // IntegerToString(barCount)
      return;
   }
   
   // We will use the static Old_Time variable to serve the bar time.
   // At each OnTick execution we will check the current bar time with the saved one.
   // If the bar time isn't equal to the saved time, it indicates that we have a new tick.
   static datetime previousTickTime;
   datetime newTickTime[1];
   bool isNewBar = false;

   // copying the last bar time to the element newTickTime[0]
   int copied = CopyTime(_Symbol,_Period, 0, 1, newTickTime);
   if(copied > 0) {
      if(previousTickTime != newTickTime[0]) {
         isNewBar = true;   // if it isn't a first call, the new bar has appeared
         /*if(MQL5InfoInteger(MQL5_DEBUGGING)) {
            Print("We have new bar here (", newTickTime[0], ") old time was ", previousTickTime, ".");
         }*/
         previousTickTime = newTickTime[0];
      }
   } else {
      // TODO: Post to Journal
      // Alert won't trigger within strategy tester
      Alert("Error in copying historical times data, error =", GetLastError());
      ResetLastError();
      return;
   }

   // EA should only check for new trade if we have a new bar
   if(isNewBar == false) {
      return;
   }
 
   // TODO: Try and get rid of this duplication. We already check this upfront onTick entry.
   barCount = Bars(_Symbol,_Period);
   if(barCount < 60) {
      // TODO: Post to Journal
      // Alert won't trigger within strategy tester
      Alert(" (Second check) EA will not activate as there are less than 60 bars. Bar count: ", barCount, "."); // IntegerToString(barCount)
      return;
   }

   //--- Define some MQL5 Structures we will use for our trade
   MqlTick latestTickPrice;         // To be used for getting recent/latest price quotes
   MqlTradeRequest mTradeRequest;   // To be used for sending our trade requests
   MqlTradeResult mTradeResult;     // To be used to get our trade results
   MqlRates mBarPriceInfo[];      // To be used to store the prices, volumes and spread of each bar
   ZeroMemory(mTradeRequest);       // Initialization of mrequest structure
   
   /*
     Let's make sure our arrays values for the Rates, ADX Values and MA values 
     is store serially similar to the timeseries array
   */
   // the rates arrays
   ArraySetAsSeries(mBarPriceInfo,true);
   // the ADX DI+values array
   ArraySetAsSeries(plsDI,true);
   // the ADX DI-values array
   ArraySetAsSeries(minDI,true);
   // the ADX values arrays
   ArraySetAsSeries(adxVal,true);
   // the MA-8 values arrays
   ArraySetAsSeries(maVal,true);
   
   // Get the last price quote using the MQL5 MqlTick Structure
   if(!SymbolInfoTick(_Symbol, latestTickPrice)) {
      // TODO: Post to Journal
      Alert("Error getting the latest price quote - error:", GetLastError(), ". ");
      return;
   }
   
   // Get the details of the latest 3 bars
   if(CopyRates(_Symbol,_Period, 0, 3, mBarPriceInfo) < 0) {
      // TODO: Post to Journal
      Alert("Error copying rates/history data - error:", GetLastError(), ". ");
      return;
   }
   
   //--- Copy the new values of our indicators to buffers (arrays) using the handle
   if(CopyBuffer(adxHandle, 0, 0, 3, adxVal) < 0 
      || CopyBuffer(adxHandle, 1, 0, 3, plsDI) < 0
      || CopyBuffer(adxHandle, 2, 0, 3, minDI) < 0) {
      // TODO: Post to Journal
      Alert("Error copying ADX indicator Buffers - error:",GetLastError(),"!!");
      return;
   }
     
   if(CopyBuffer(maHandle, 0, 0, 3, maVal) < 0) {
      // TODO: Post to Journal
      Alert("Error copying Moving Average indicator buffer - error:",GetLastError());
      return;
   }
   
   // FIXME: Why index 1?
   priceClose = mBarPriceInfo[1].close;
   
   // Dont open any new trades if 1 still exists, regardless of who opened it.
    bool buyOpened = false;
    bool sellOpened = false;
    
    if (PositionSelect(_Symbol) == true) {
      // we have an opened position, now check the type
      if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
         buyOpened = true;
      }
      else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
         sellOpened = true;
      } else {
         // TODO: Post to Journal
         Print("Unexpected Position type! EA will not continue execution. PositionGetInteger(", POSITION_TYPE, ") returned: ", PositionGetInteger(POSITION_TYPE));
         return;
      }
   }
   
   // Now we can place either a Buy or Sell order
   // Set generic order info
   mTradeRequest.action = TRADE_ACTION_DEAL;                                    // immediate order execution
   mTradeRequest.symbol = _Symbol;                                              // currency pair
   mTradeRequest.volume = Lot;                                                  // number of lots to trade
   mTradeRequest.magic = EAMagic;                                              // Order Magic Number
   mTradeRequest.type_filling = ORDER_FILLING_FOK;                              // Order execution type
   mTradeRequest.deviation = 100;                                                 // Deviation from current price
   mTradeRequest.type = NULL;
   
   if (buyOpened) {
      // TODO: Post to journal
      Print("EA is skipping checks for Buy Position as there is currently at least 1 open Buy position."); 
   } else {
      /*
         Check for a long/Buy Setup : 
            MA-8 increasing upwards, 
            Previous price close above it, 
            ADX > 22, 
            +DI > -DI
      */
      // Declare bool type variables to hold our Buy Conditions
      bool Buy_Condition_1 = (maVal[0] > maVal[1]) && (maVal[1] > maVal[2]);  // MA-8 Increasing upwards
      bool Buy_Condition_2 = (priceClose > maVal[1]);                         // previuos price closed above MA-8
      bool Buy_Condition_3 = (adxVal[0] > AdxMin);                           // Current ADX value greater than minimum value (22)
      bool Buy_Condition_4 = (plsDI[0] > minDI[0]);                           // +DI greater than -DI
   
      // Print(StringFormat("Buy conditions: 1 = %s, 2 = %s, 3 = %s, 4 = %s", Buy_Condition_1 ? "True" : "False", Buy_Condition_2 ? "True" : "False", Buy_Condition_3 ? "True" : "False", Buy_Condition_4 ? "True" : "False"));
   
      if(Buy_Condition_1 && Buy_Condition_2) {
         if(Buy_Condition_3 && Buy_Condition_4) {
            mTradeRequest.price = NormalizeDouble(latestTickPrice.ask, _Digits);            // latest ask price
            mTradeRequest.sl = NormalizeDouble(latestTickPrice.ask - stopLoss * _Point,_Digits); // Stop Loss
            mTradeRequest.tp = NormalizeDouble(latestTickPrice.ask + takeProfit * _Point,_Digits); // Take Profit
            mTradeRequest.type = ORDER_TYPE_BUY;                                         // Buy Order
            
            if (!CheckStopLossAndTakeprofit(mTradeRequest.type, latestTickPrice.ask, mTradeRequest.sl, mTradeRequest.tp)) {
               return;
            }
         }
      }
   }
   
   if (sellOpened) {
      // TODO: Post to journal
      Print("EA is skipping checks for Sell Position as there is currently at least 1 open Sell position."); 
   } else {
      /*
         Check for a Short/Sell Setup : 
            MA-8 decreasing downwards, 
            Previous price close below it, 
            ADX > 22, 
            -DI > +DI
      */
      // Declare bool type variables to hold our Sell Conditions
      bool Sell_Condition_1 = (maVal[0] < maVal[1]) && (maVal[1] < maVal[2]);    // MA-8 decreasing downwards
      bool Sell_Condition_2 = (priceClose < maVal[1]);                              // Previous price closed below MA-8
      bool Sell_Condition_3 = (adxVal[0] > AdxMin);                             // Current ADX value greater than minimum (22)
      bool Sell_Condition_4 = (plsDI[0] < minDI[0]);                             // -DI greater than +DI
      
      // Print(StringFormat("Sell conditions: 1 = %s, 2 = %s, 3 = %s, 4 = %s", Sell_Condition_1 ? "True" : "False", Sell_Condition_2 ? "True" : "False", Sell_Condition_3 ? "True" : "False", Sell_Condition_4 ? "True" : "False"));
      
      if(Sell_Condition_1 && Sell_Condition_2) {
         if(Sell_Condition_3 && Sell_Condition_4) {
            // Do we have enough cash to place an order?
            ValidateFreeMargin(_Symbol, Lot, ORDER_TYPE_SELL);
            
            mTradeRequest.price = NormalizeDouble(latestTickPrice.bid, _Digits);           // latest Bid price
            mTradeRequest.sl = NormalizeDouble(latestTickPrice.bid + stopLoss * _Point, _Digits); // Stop Loss
            mTradeRequest.tp = NormalizeDouble(latestTickPrice.bid - takeProfit * _Point, _Digits); // Take Profit
            mTradeRequest.type = ORDER_TYPE_SELL;                                         // Sell Order
         }
      }
   }

   if (mTradeRequest.type == NULL) {
      Print("Order conditions not met. No position will be opened.");
      return;
   }

   // Validate SL and TP
   if (!CheckStopLossAndTakeprofit(mTradeRequest.type, latestTickPrice.bid, mTradeRequest.sl, mTradeRequest.tp)) {
      return;
   }

   // Do we have enough cash to place an order?
   if (!ValidateFreeMargin(_Symbol, Lot, mTradeRequest.type)) {
      Print("Insufficient funds in account. Disable this EA until you sort that out.");
      return;
   }

   // Place the order
   if (OrderSend(mTradeRequest, mTradeResult)) {
      // Basic validation passed so check returned result now
      // Request is completed or order placed 
      if(mTradeResult.retcode == 10009 || mTradeResult.retcode == 10008) {
         // TODO: buyTickets[next] = mTradeResult.order;
         Print("A Buy order has been successfully placed with Ticket#:", mTradeResult.order, ". ");
      } else {
         // TODO: Post to journal
         Print("Unexpected Order result code. Buy order may not have been created. mTradeResult.retcode is: ", mTradeResult.retcode, ".");
         return;
      }
   } else {
      // TODO: Post to journal
      int errorCode = GetLastError();
      Print(StringFormat("New order request could not be completed. Error: %d. Result comment: %s.", errorCode, mTradeResult.comment));
      ResetLastError();
      return;
   }
}

//MqlTradeResult{  retcode:10016 deal:0 order:0 volume:0.0 price:0.0 bid:0.0 ask:0.0 comment:"Invalid stops" request_id:0 retcode_external:0 reserved:[124] }
