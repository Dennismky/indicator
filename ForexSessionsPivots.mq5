//+------------------------------------------------------------------+
//| ForexSessionsPivots.mq5                                          |
//| Tokyo, London and New York session boxes plus daily pivot points |
//+------------------------------------------------------------------+
#property copyright   "Dennismky"
#property version     "1.00"
#property description "Session boxes follow each city's daylight saving. Pivots use the previous trading day."
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   5

#property indicator_label1  "Pivot"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrSilver
#property indicator_width1  1
#property indicator_label2  "R1"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrTomato
#property indicator_width2  1
#property indicator_label3  "R2"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrTomato
#property indicator_style3  STYLE_DOT
#property indicator_label4  "S1"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrMediumSeaGreen
#property indicator_width4  1
#property indicator_label5  "S2"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrMediumSeaGreen
#property indicator_style5  STYLE_DOT

input group "Sessions"
input bool  InpShowSessions   = true;              // Show session boxes (H1 and lower)
input int   InpDaysBack       = 20;                // Days of sessions to draw
input bool  InpShowLabels     = true;              // Show session names
input color InpTokyoColor     = C'32,62,74';       // Tokyo colour
input color InpLondonColor    = C'30,52,104';      // London colour
input color InpNewYorkColor   = C'70,40,100';      // New York colour
input group "Server clock"
input int   InpServerGmtHours = 0;                 // Server GMT offset in hours (0 = detect)
input bool  InpServerUsDst    = true;              // Server clock follows US daylight saving

const string PREFIX = "FSP_";

double PivotBuffer[], R1Buffer[], R2Buffer[], S1Buffer[], S2Buffer[];

//+------------------------------------------------------------------+
//| Date helpers                                                     |
//+------------------------------------------------------------------+
datetime MakeDate(const int year, const int month, const int day, const int hour = 0)
  {
   MqlDateTime d;
   d.year = year; d.mon = month; d.day = day; d.hour = hour; d.min = 0; d.sec = 0;
   return StructToTime(d);
  }

int DayOfWeek(const datetime t)
  {
   MqlDateTime d;
   TimeToStruct(t, d);
   return d.day_of_week;
  }

int YearOf(const datetime t)
  {
   MqlDateTime d;
   TimeToStruct(t, d);
   return d.year;
  }

// n-th Sunday of a month (1 = first).
datetime NthSunday(const int year, const int month, const int n, const int hour)
  {
   datetime first = MakeDate(year, month, 1, hour);
   int shift = (7 - DayOfWeek(first)) % 7;
   return first + (shift + 7 * (n - 1)) * 86400;
  }

datetime LastSunday(const int year, const int month, const int hour)
  {
   int nextYear = (month == 12) ? year + 1 : year;
   int nextMonth = (month == 12) ? 1 : month + 1;
   datetime last = MakeDate(nextYear, nextMonth, 1, hour) - 86400;
   return last - DayOfWeek(last) * 86400;
  }

// US clocks change at 02:00 local: 07:00 UTC in March, 06:00 UTC in November.
bool UsDst(const datetime utc)
  {
   int y = YearOf(utc);
   return utc >= NthSunday(y, 3, 2, 7) && utc < NthSunday(y, 11, 1, 6);
  }

// UK clocks change at 01:00 UTC on the last Sunday of March and October.
bool UkDst(const datetime utc)
  {
   int y = YearOf(utc);
   return utc >= LastSunday(y, 3, 1) && utc < LastSunday(y, 10, 1);
  }

// Seconds to add to a UTC time to get broker server time on that date.
int ServerOffset(const datetime utc)
  {
   int now = (InpServerGmtHours != 0)
             ? InpServerGmtHours * 3600
             : (int)MathRound((double)(TimeTradeServer() - TimeGMT()) / 1800.0) * 1800;
   if(InpServerGmtHours == 0 && InpServerUsDst)
      now += ((UsDst(utc) ? 1 : 0) - (UsDst(TimeGMT()) ? 1 : 0)) * 3600;
   return now;
  }

//+------------------------------------------------------------------+
//| Session boxes                                                    |
//+------------------------------------------------------------------+
void DrawBox(const string name, const string label, const datetime utcStart, const datetime utcEnd, const color clr)
  {
   string box = PREFIX + name + "_" + TimeToString(utcStart, TIME_DATE);
   string text = box + "_t";
   datetime from = utcStart + ServerOffset(utcStart);
   datetime to   = MathMin(utcEnd + ServerOffset(utcEnd) - 1, TimeTradeServer());
   double highs[], lows[];
   if(from > TimeTradeServer() || CopyHigh(_Symbol, _Period, from, to, highs) <= 0 || CopyLow(_Symbol, _Period, from, to, lows) <= 0)
     {
      ObjectDelete(0, box);
      ObjectDelete(0, text);
      return;
     }
   double high = highs[ArrayMaximum(highs)];
   double low  = lows[ArrayMinimum(lows)];

   if(ObjectFind(0, box) < 0)
     {
      ObjectCreate(0, box, OBJ_RECTANGLE, 0, from, high, to, low);
      ObjectSetInteger(0, box, OBJPROP_FILL, true);
      ObjectSetInteger(0, box, OBJPROP_BACK, true);
      ObjectSetInteger(0, box, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, box, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, box, OBJPROP_COLOR, clr);
     }
   ObjectMove(0, box, 0, from, high);
   ObjectMove(0, box, 1, to, low);

   if(!InpShowLabels)
      return;
   if(ObjectFind(0, text) < 0)
     {
      ObjectCreate(0, text, OBJ_TEXT, 0, from, high);
      ObjectSetString(0, text, OBJPROP_TEXT, label);
      ObjectSetInteger(0, text, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, text, OBJPROP_COLOR, clrDarkGray);
      ObjectSetInteger(0, text, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, text, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, text, OBJPROP_HIDDEN, true);
     }
   ObjectMove(0, text, 0, from, high);
  }

void DrawSessions()
  {
   if(!InpShowSessions || PeriodSeconds() > 3600)
     {
      ObjectsDeleteAll(0, PREFIX);
      return;
     }
   datetime today = TimeGMT() - TimeGMT() % 86400;
   for(int i = 0; i < InpDaysBack; i++)
     {
      datetime day = today - i * 86400;
      int dow = DayOfWeek(day);
      if(dow == SUNDAY || dow == SATURDAY)
         continue;
      datetime noon = day + 12 * 3600;
      int london = UkDst(noon) ? 7 : 8;   // 08:00-17:00 London time, in UTC
      int newYork = UsDst(noon) ? 12 : 13; // 08:00-17:00 New York time, in UTC
      DrawBox("tokyo", "Tokyo", day, day + 9 * 3600, InpTokyoColor);   // 09:00-18:00 Tokyo time, no daylight saving
      DrawBox("london", "London", day + london * 3600, day + (london + 9) * 3600, InpLondonColor);
      DrawBox("newyork", "New York", day + newYork * 3600, day + (newYork + 9) * 3600, InpNewYorkColor);
     }
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Indicator                                                        |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, PivotBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, R1Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, R2Buffer, INDICATOR_DATA);
   SetIndexBuffer(3, S1Buffer, INDICATOR_DATA);
   SetIndexBuffer(4, S2Buffer, INDICATOR_DATA);
   for(int i = 0; i < 5; i++)
      PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   IndicatorSetString(INDICATOR_SHORTNAME, "Forex Sessions & Pivots");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, PREFIX);
   ChartRedraw();
  }

void SetEmpty(const int i)
  {
   PivotBuffer[i] = EMPTY_VALUE;
   R1Buffer[i] = EMPTY_VALUE;
   R2Buffer[i] = EMPTY_VALUE;
   S1Buffer[i] = EMPTY_VALUE;
   S2Buffer[i] = EMPTY_VALUE;
  }

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   ArraySetAsSeries(time, false);
   if(Bars(_Symbol, PERIOD_D1) < 3)
      return 0; // daily history is still loading; MT5 calls again

   bool intraday = PeriodSeconds() < 86400;
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   datetime cachedDay = 0;
   double p = 0, r1 = 0, r2 = 0, s1 = 0, s2 = 0;
   bool valid = false;

   for(int i = start; i < rates_total; i++)
     {
      datetime day = time[i] - time[i] % 86400;
      if(day != cachedDay)
        {
         cachedDay = day;
         valid = false;
         int shift = intraday ? iBarShift(_Symbol, PERIOD_D1, day, false) : -1;
         if(shift >= 0)
           {
            int prev = (iTime(_Symbol, PERIOD_D1, shift) == day) ? shift + 1 : shift;
            // Some brokers print a short Sunday candle; Monday's levels should come from Friday.
            while(prev < Bars(_Symbol, PERIOD_D1) && DayOfWeek(iTime(_Symbol, PERIOD_D1, prev)) == SUNDAY)
               prev++;
            if(prev < Bars(_Symbol, PERIOD_D1))
              {
               double h = iHigh(_Symbol, PERIOD_D1, prev);
               double l = iLow(_Symbol, PERIOD_D1, prev);
               double c = iClose(_Symbol, PERIOD_D1, prev);
               p = (h + l + c) / 3.0;
               r1 = 2.0 * p - l;
               s1 = 2.0 * p - h;
               r2 = p + (h - l);
               s2 = p - (h - l);
               valid = (h > 0 && l > 0);
              }
           }
        }
      // The first bar of each day stays empty so levels step cleanly instead of slanting between days.
      bool newDay = (i > 0 && time[i - 1] - time[i - 1] % 86400 != day);
      if(!valid || newDay)
        {
         SetEmpty(i);
         continue;
        }
      PivotBuffer[i] = p;
      R1Buffer[i] = r1;
      R2Buffer[i] = r2;
      S1Buffer[i] = s1;
      S2Buffer[i] = s2;
     }

   static datetime lastBar = 0;
   if(prev_calculated == 0 || time[rates_total - 1] != lastBar)
     {
      lastBar = time[rates_total - 1];
      DrawSessions();
     }
   return rates_total;
  }
//+------------------------------------------------------------------+
