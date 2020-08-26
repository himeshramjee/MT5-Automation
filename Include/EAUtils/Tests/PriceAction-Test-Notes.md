
# Test notes

1. S5: Price Action, 15M Chart, 20EMA, 5usd loss limit per trade, 3 Open position limit, 2 Lots per trade, Daily P/L targets 9999, Close each day, TP at 23usd, Don't force trend alignment
   * 07/15 -> Start with 200usd and ended day with 207.85, no stop out
   * 07/08 -> Start with 200usd and ended day with -217.21, 97% stop out ***NEGATIVE BALANCE - Investigate more***
      * -> Rest of Aug is profitable each day.
   * 01/01/2020 till 24/08/2020 -> Start with 200usd and ended period with 100455.29, no stop out, 
      * -> 230 days traded, 224 profitable days 6 loss days, 
      * -> Avg 436.76 USD per day, Lowest profit for a day was 20.15, Highest loss for a day was -4.72usd
      * -> No failed orders, 7788 Sell orders placed, 9342 Buy orders placed, 10277 orders hit SL of 5 usd, 374 signals missed due to insufficient free margin.
1. Pattern tests (ADDED in order):
   1. 01/08 till 26/08/2020
      1. 3 Black Crows + 3 White Soldiers
         * 2884.79, 5 losing days, 160 Max margin, -9.98 Max FL
      1. Dark Cloud Cover + Piercing Lines
         * 4531.03, 3 losing days, 160 Max margin, -9.98 Max FL
      1. Evening Doji + Morning Doji
         * 4531.03, 3 losing days, 160 Max margin, -9.98 Max FL
      1. Bearish Engulfing + Bullish Engulfing
         * 7855.07, 2 losing days, 160 Max margin, -9.98 Max FL
      1. Bearish Harami + Bullish Harami
         * 11221.62, 1 losing days, 160 Max margin, -9.98 Max FL
      1. Evening Star + Morning Star
         * 11297.09, 1 losing days, Highest loss day -386.15, 160 Max margin, -9.98 Max FL
      1. Bearish Meeting Lines + Bullish Meeting Lines
         * 11297.09, 1 losing days, Highest loss day -386.15, 160 Max margin, -9.98 Max FL
   
1. Pattern testing with/without Evening Star + Doji, Morning Star + Doji, Bearish + Bullish Meeting Lines Main patterns
   1. 01/07 till 31/07/2020
      1. Without: 13042.80, 0 losing days, Lowest Profit day 31.25, 159.61 Max margin, -9.98 Max FL
      1. With: 13353.21, 0 losing days, Lowest Profit day 61.46, 159.61 Max margin, -9.98 Max FL
   
   1. 01/06 till 30/06/2020
      1. Without: 12808.31, 0 losing days, Lowest Profit day 36.31, 150.12 Max margin, -9.98 Max FL
      1. With: 13291.27, 0 losing days, Lowest Profit day 36.31, 150.12 Max margin, -9.98 Max FL
   
   1. 01/05 till 31/05/2020
      1. Without: 12142.64, 1 losing days, Highest loss day -66.07, 147.17 Max margin, -9.98 Max FL
      1. With: 12408.37, 2 losing days, Highest loss day -15.30, 147.17 Max margin, -9.98 Max FL
   
   1. 01/04 till 30/04/2020
      1. Without: 12235.25, 1 losing days, Highest loss day -157.96, 147.53 Max margin, -9.98 Max FL
      1. With: 12403.40, 1 losing days, Highest loss day -182.93, 147.53 Max margin, -9.98 Max FL
   
   1. 01/03 till 31/03/2020
      1. Without: 10501.94, 1 losing days, Highest loss day -10.00, 153.71 Max margin, -9.98 Max FL
      1. With: 11411.34, 0 losing days, Lowest Profit day 67.72, 153.71 Max margin, -9.98 Max FL
   
   1. 01/02 till 29/02/2020
      1. Without: 14095.73, 1 losing days, Highest loss day -5.90, 157.38 Max margin, -9.98 Max FL
      1. With: 14502.14, 1 losing days, Lowest Profit day 55.71, 157.38 Max margin, -9.98 Max FL
   
   1. 01/01 till 31/01/2020
      1. Without: 10432.88, 2 losing days, Lowest Profit day -4.72, 140.95 Max margin, -9.98 Max FL
      1. With: 10629.60, 2 losing days, Lowest Profit day -4.72, 140.95 Max margin, -9.98 Max FL