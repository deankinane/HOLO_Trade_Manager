//+------------------------------------------------------------------+
//|                                           HOLO_Trade_Manager.mq4 |
//|                                            Copyright 2020, Aeson |
//|                               https://www.forexfactory.com/aeson |
//+------------------------------------------------------------------+
//#include <WinUser32.mqh>
//#import "user32.dll"
//int GetAncestor(int, int);

class TrailingStop {
public:
   int Ticket;
   int Pips;
   TrailingStop() {
      Ticket=0; 
      Pips=0;
   };
   TrailingStop(int ticket, int pips){
      Ticket = ticket;
      Pips = pips;
   };
};

#property copyright "Copyright 2020, Aeson"
#property link      "https://www.forexfactory.com/aeson"
#define VERSION "1.02"
#property version VERSION
#property strict

extern double RiskPerTrade = 1.0;
extern bool DrawHoLoLevels = true;
extern bool DrawSymbolInfo = true;
extern bool DrawEntryMarkers = true;
extern bool DrawPipProfitLevels = true;
extern bool ShowAlerts = false;
extern bool ShowMotivationalMessage = true;

int FivePipIntervals = 6;

int TesterSpeed = 500;

int MoveStopPips = 1;
int MagicNumber = 69420;

TrailingStop TrailingOrders[];

const string DefaultFont = "Courier";

long chartId;

string _YesHigh = "YesHigh";
string _YesLow = "YesLow";
string _DayHigh = "DayHigh";
string _DayLow = "DayLow";
string _OpenHigh = "OpenHigh";
string _OpenLow = "OpenLow";

string _ShortEntry = "_ShortEntry";
string _LongEntry = "_LongEntry";
string _DayStartLine = "_DayStartLine";

string _LabelSpread = "LblSpread";
string _LabelSpreadMinMax = "LabelSpreadMinMax";
string _LabelSymbol = "_LabelSymbol";
string _LabelTimeToClose = "LabelTimeToClose";
string _LabelTimeToH1Close = "_LabelTimeToH1Close";
string lblAuthor = "lblAuthor";
string lblTitle = "lblTitle";

string _BtnSellStop = "_BtnSellStop";
string _BtnBuyStop = "_BtnBuyStop";
string _BtnCloseOrder = "_BtnCloseOrder";
string _BtnMoveToBreakEven = "_BtnMoveToBreakEven";
string _BtnPlusPip = "_BtnPlusPip";
string _BtnMinusPip = "_BtnMinusPip";
string _BtnSetTrailingStop = "_BtnSetTrailingStop";

string _LblEmotions = "_LblEmotions";

double DailyHigh, DailyLow, OpenHigh, OpenLow, YesterdayHigh, YesterdayLow;
datetime DailyHighTime, DailyLowTime, OpenHighTime, OpenLowTime;

double ShortEntry, LongEntry;
long Spread;
long SpreadMin = 999, SpreadMax = -1;
double SpreadPrice;
double EntrySpreadSprice = 0.0003;
double Factor;
double SinglePip;

bool pauseHighPrimed = true;
bool pauseLowPrimed = true;

string Alerts[];
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
   chartId = ChartID();
   Factor = MathPow(10, Digits());
   SinglePip = 10/Factor;
   ArrayResize(TrailingOrders, 0);
   EventSetTimer(1);
   
   CreateTradeButtons();
   
   DrawEmotionLabels();
   
   OnTick();

//---
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---
   DeleteStaticObjects();
   DeleteObjects();
   DeleteTradeButtons();
   EventKillTimer();
   ObjectDelete(_LabelTimeToClose);
   
   DeleteEmotionLabels();
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
//---
   CalculateValues();

   DeleteObjects();
   DrawLines();
   DrawInfo();

   DeleteStaticObjects();
   DrawStaticObjects();
   
   TesterWorkarounds();
   
   if (ObjectFind(_BtnBuyStop) < 0){
      CreateTradeButtons();
   }
   
   MoveTrailingStops();
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer() {

   ObjectDelete(_LabelTimeToClose);
   
   if (DrawSymbolInfo) {
      long leftTime =(Period()*60)-(TimeCurrent()-Time[0]);
      DrawLabel(_LabelTimeToClose, "Bar Close: " + TimeToStr(leftTime,TIME_SECONDS), clrWhite, 12, 20, 130, CORNER_RIGHT_UPPER, "Arial Bold");
   }
   
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalculateValues() {
   SymbolInfoInteger(NULL, SYMBOL_SPREAD, Spread);
   SpreadMin = Spread < SpreadMin ? Spread : SpreadMin;
   SpreadMax = Spread > SpreadMax ? Spread : SpreadMax;

   int barShift = iBarShift(NULL, PERIOD_H1, iTime(NULL, PERIOD_D1, 0)) + 1;

   int highOpen = iHighest(NULL, PERIOD_H1, MODE_OPEN, barShift);
   OpenHigh = iOpen(NULL, PERIOD_H1, highOpen);
   OpenHighTime = iTime(NULL, PERIOD_H1, highOpen);

   int lowOpen = iLowest(NULL, PERIOD_H1, MODE_OPEN, barShift);
   OpenLow = iOpen(NULL, PERIOD_H1, lowOpen);
   OpenLowTime = iTime(NULL, PERIOD_H1, lowOpen);

   int dayHigh = iHighest(NULL, PERIOD_H1, MODE_HIGH, barShift);
   DailyHigh = iHigh(NULL, PERIOD_D1, 0);
   DailyHighTime = iTime(NULL, PERIOD_H1, dayHigh);

   int dayLow = iLowest(NULL, PERIOD_H1, MODE_LOW, barShift);
   DailyLow = iLow(NULL, PERIOD_D1, 0);
   DailyLowTime = iTime(NULL, PERIOD_H1, dayLow);

   YesterdayHigh = iHigh(NULL, PERIOD_D1, 1);
   YesterdayLow =  iLow(NULL, PERIOD_D1, 1);

   SpreadPrice = NormalizeDouble(((double)Spread)/Factor, Digits());

   ShortEntry = NormalizeDouble(OpenHigh, Digits());
   LongEntry = NormalizeDouble(OpenLow + SpreadPrice, Digits()) ;
}

void DrawLines() {

   if (DrawHoLoLevels) {
      if (YesterdayHigh < DailyHigh) {
         DrawHLine(_YesHigh, iTime(NULL, PERIOD_D1, 1), iHigh(NULL, PERIOD_D1, 1), clrDarkGreen, STYLE_SOLID, "Yesterday High", 0, clrDimGray);
      } else {
         DrawHLine(_YesHigh, iTime(NULL, PERIOD_D1, 1), iHigh(NULL, PERIOD_D1, 1), clrLimeGreen, STYLE_SOLID, "Yesterday High");
      }
   
      if (YesterdayLow > DailyLow) {
         DrawHLine(_YesLow, iTime(NULL, PERIOD_D1, 1), iLow(NULL, PERIOD_D1, 1), clrMaroon, STYLE_SOLID, "Yesterday Low", 0, clrDimGray);
      } else {
         DrawHLine(_YesLow, iTime(NULL, PERIOD_D1, 1), iLow(NULL, PERIOD_D1, 1), clrRed, STYLE_SOLID, "Yesterday Low");
      }
   
      DrawHLine(_DayHigh, DailyHighTime, DailyHigh, clrLimeGreen, STYLE_DASH, "High");
   
   
      DrawHLine(_DayLow, DailyLowTime, DailyLow, clrRed, STYLE_DASH, "Low");
   
   
      DrawHLine(_OpenHigh, OpenHighTime, OpenHigh, clrLightGreen, STYLE_DASH, "Open", 0, clrLightGreen);
   
   
      DrawHLine(_OpenLow, OpenLowTime, OpenLow, clrPink, STYLE_DASH, "Open", 0, clrPink);
   }


   if (SelectOrder()) {
      if (DrawPipProfitLevels) {
         if(OrderType() == OP_SELLSTOP || OrderType() == OP_SELL) {
            DrawShortPipMarkers(OrderOpenPrice());
         } else if (OrderType() == OP_BUYSTOP || OrderType() == OP_BUY) {
            DrawLongPipMarkers(OrderOpenPrice());
         }
      }
   } else {
      if (ValidShortEntry()) {
         if (DrawEntryMarkers) DrawEntryLine(_ShortEntry, ShortEntry, clrPink, STYLE_DASH, "Short Entry @ " + DoubleToString(ShortEntry, Digits()));
         if (DrawPipProfitLevels) DrawShortPipMarkers();
         //PauseStrategyTester();
         ShowAlert(Symbol(), Time[0], "SHORT");

      } else {
         pauseHighPrimed = true;
      }
   
      if (ValidLongEntry()) {
         if (DrawEntryMarkers) DrawEntryLine(_LongEntry, LongEntry, clrLightGreen, STYLE_DASH, "Long Entry @ " + DoubleToString(LongEntry, Digits()));
         if (DrawPipProfitLevels) DrawLongPipMarkers();
         //PauseStrategyTester();
         ShowAlert(Symbol(), Time[0], "LONG");
         
      } else {
         pauseLowPrimed = true;
      }
   }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteObjects() {
   ObjectDelete(_YesHigh);
   ObjectDelete(_YesHigh+"label");
   ObjectDelete(_YesLow);
   ObjectDelete(_YesLow+"label");

   ObjectDelete(_DayHigh);
   ObjectDelete(_DayHigh+"label");
   ObjectDelete(_DayLow);
   ObjectDelete(_DayLow+"label");

   ObjectDelete(_OpenHigh);
   ObjectDelete(_OpenHigh+"label");
   ObjectDelete(_OpenLow);
   ObjectDelete(_OpenLow+"label");

   
   ObjectDelete(_ShortEntry);
   ObjectDelete(_ShortEntry+"label");
   ObjectDelete(_LongEntry);
   ObjectDelete(_LongEntry+"label");

   ObjectDelete(_LabelSymbol);
   ObjectDelete(_LabelSpread);
   ObjectDelete(_LabelSpreadMinMax);

   ObjectDelete(lblAuthor);
   ObjectDelete(lblTitle);
   
   for(int i=1; i<=FivePipIntervals*5; i++) {
      ObjectDelete("PIP"+(string)i);
      ObjectDelete("PIP"+(string)i+"label");
   }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawHLine(string name, datetime time, double price, double colour, int style, string label, int offset = 0, color textColour = clrWhite) {
   ObjectCreate(name, OBJ_TREND, 0, Time[0]+Period()*(120+offset), price, time, price);
   ObjectSet(name, OBJPROP_COLOR, colour);
   ObjectSet(name, OBJPROP_STYLE, style);
   ObjectSet(name, OBJPROP_RAY_RIGHT, false);

   datetime time3 = Time[0]+Period()*(180+offset);
   string labelName = name+"label";

   ObjectCreate(labelName, OBJ_TEXT, 0, time3, price);
   ObjectSet(labelName,OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetText(labelName,label,8,DefaultFont,textColour);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawEntryLine(string name, double price, double colour, int style, string label) {
   datetime time1 = Time[0]+Period()*500;

   ObjectCreate(name, OBJ_TREND, 0, time1, price, Time[0], price);
   ObjectSet(name, OBJPROP_COLOR, colour);
   ObjectSet(name, OBJPROP_STYLE, style);
   ObjectSet(name, OBJPROP_RAY_RIGHT, false);

   string labelName = name+"label";

   ObjectCreate(labelName, OBJ_TEXT, 0, time1+Period()*60, price);
   ObjectSet(labelName,OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetText(labelName,label,8,DefaultFont,clrWhite);
   ObjectSet(labelName, OBJPROP_ZORDER, 50);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawLabel(string name, string text, color colour, int size, int x, int y, int anchor = CORNER_LEFT_UPPER, string font = "") {
   ObjectCreate(name, OBJ_LABEL, 0, 0, 0);
   ObjectSetText(name,text,size,font == "" ? DefaultFont : font,colour);
   ObjectSet(name,OBJPROP_XDISTANCE,x);
   ObjectSet(name,OBJPROP_YDISTANCE,y);
   ObjectSet(name, OBJPROP_CORNER, anchor);

   if (anchor == CORNER_RIGHT_UPPER) {
      ObjectSet(name, OBJPROP_ANCHOR, ANCHOR_RIGHT);
   }
}

void DrawInfo() {
   if (DrawSymbolInfo) {
      DrawLabel(_LabelSymbol, _Symbol + " " + PeriodName(_Period), clrWhite, 20, 20, 50, CORNER_RIGHT_UPPER, "Arial Bold");
      DrawLabel(_LabelSpread, "Spread: " + (string)Spread + " points", clrWhite, 14, 20, 82, CORNER_RIGHT_UPPER, "Arial");
      DrawLabel(_LabelSpreadMinMax, "Min: " + (string)SpreadMin + " / Max: " + (string)SpreadMax, clrWhite, 10, 20, 104, CORNER_RIGHT_UPPER, "Arial");
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawShortPipMarkers(double entry = 0) {
   entry = entry > 0 ? entry - EntrySpreadSprice : ShortEntry - SpreadPrice;
   
   
   for(int i=1; i<=FivePipIntervals*5; i++) {
      if (i%5==0) {
         DrawHLine("PIP"+(string)i, Time[0], entry-(SinglePip*i), clrGray, STYLE_DOT, "+" + (string)(i), -10, clrGray);
      } else {
         DrawHLine("PIP"+(string)i, Time[0], entry-(SinglePip*i), clrGray, STYLE_DOT, "", -15, clrGray);
      }
      
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawLongPipMarkers(double entry = 0) {

   entry = entry > 0 ? entry : LongEntry + SpreadPrice;

   for(int i=1; i<=FivePipIntervals*5; i++) {
      
      if (i%5==0) {
         DrawHLine("PIP"+(string)i, Time[0], entry+(SinglePip*i), clrGray, STYLE_DOT, "+" + (string)(i), -10, clrGray);
      } else {
         DrawHLine("PIP"+(string)i, Time[0], entry+(SinglePip*i), clrGray, STYLE_DOT, "", -15, clrGray);
      }
   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawStaticObjects() {
   DrawLabel(lblTitle, "HOLO Trade Manager " + (string)VERSION, clrWhite, 16, 10, 30, CORNER_LEFT_UPPER, "Arial Bold");
   DrawLabel(lblAuthor, "Created by Aeson  -  Inspired by TooSlow", clrWhiteSmoke, 8, 10, 55, CORNER_LEFT_UPPER, "Arial");
   
   ObjectCreate(_DayStartLine, OBJ_VLINE, 0, iTime(NULL, PERIOD_D1, 0), 0);
   ObjectSet(_DayStartLine, OBJPROP_COLOR, clrGray);
   ObjectSet(_DayStartLine, OBJPROP_STYLE, STYLE_DOT);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteStaticObjects() {
   ObjectDelete(_DayStartLine);
   ObjectDelete(lblTitle);
   ObjectDelete(lblAuthor);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//void PauseStrategyTester() {
//   if (!pauseHighPrimed || !pauseLowPrimed) return;
//   int hmain;
//  if (IsTesting() && IsVisualMode()) {
//      pauseHighPrimed = false;
//      pauseLowPrimed = false;
//     hmain = GetAncestor(WindowHandle(Symbol(), Period()), 2 /* GA_ROOT */);
//      PostMessageA(hmain, WM_COMMAND, 0x57a, 0);
//   }
//}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateButton(string name, string label, int x, int y, int width, int height,
                  color bgColor = C'236,233,216', color textColor = clrBlack, int anchor = CORNER_RIGHT_UPPER) {
   ObjectCreate(name, OBJ_BUTTON, 0, 0, 0);
   ObjectSet(name,OBJPROP_XDISTANCE,x+width);
   ObjectSet(name,OBJPROP_YDISTANCE,y);
   ObjectSet(name,OBJPROP_WIDTH,x);
   ObjectSet(name,OBJPROP_XSIZE,width);
   ObjectSet(name,OBJPROP_YSIZE,height);
   ObjectSet(name, OBJPROP_CORNER, anchor);
   ObjectSet(name, OBJPROP_BGCOLOR, bgColor);
   ObjectSet(name, OBJPROP_COLOR, textColor);
   ObjectSet(name, OBJPROP_ZORDER, 100);
   ObjectSetText(name, label, 12);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateTradeButtons() {
   CreateButton(_BtnBuyStop, "Buy Stop", 110, 180, 80, 26, clrGreen, clrWhite);
   CreateButton(_BtnSellStop, "Sell Stop", 20, 180, 80, 26, clrRed, clrWhite);

   CreateButton(_BtnMoveToBreakEven, "Move Stop to BE + " + (string)MoveStopPips, 50, 216, 140, 26, clrLightSteelBlue);

   CreateButton(_BtnPlusPip, "+", 20, 216, 20, 13, clrLightSteelBlue);
   CreateButton(_BtnMinusPip, "-", 20, 229, 20, 13, clrLightSteelBlue);

   CreateButton(_BtnSetTrailingStop, "Set Trailing Stop", 20, 252, 170, 26, clrLightSteelBlue);

   CreateButton(_BtnCloseOrder, "Close Open/Pending", 20, 288, 170, 26, clrPink, clrDarkRed);

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteTradeButtons() {
   ObjectDelete(_BtnSellStop);
   ObjectDelete(_BtnBuyStop);
   ObjectDelete(_BtnMoveToBreakEven);
   ObjectDelete(_BtnPlusPip);
   ObjectDelete(_BtnMinusPip);
   ObjectDelete(_BtnCloseOrder);
   ObjectDelete(_BtnSetTrailingStop);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ValidShortEntry() {

   int period = Period() < PERIOD_H1 ? Period() : PERIOD_M15;
   return iOpen(NULL, period, 0) > OpenHigh && iHigh(NULL, PERIOD_H1, 0) < DailyHigh && Bid > ShortEntry;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ValidLongEntry() {

   int period = Period() < PERIOD_H1 ? Period() : PERIOD_M15;   
   return iOpen(NULL, period, 0) < OpenLow && iLow(NULL, PERIOD_H1, 0) > DailyLow && Ask < LongEntry;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string PeriodName(long period) {
   string period_xxx = EnumToString((ENUM_TIMEFRAMES)period);
   return StringSubstr(period_xxx, 7);
}

// Calculate the size of the position size
double CalculateLotSize(double SL) {
   double LotSize=0;
//We get the value of a tick
   double nTickValue=MarketInfo(Symbol(),MODE_TICKVALUE);
//If the digits are 3 or 5 we normalize multiplying by 10
   if(Digits==3 || Digits==5) {
      nTickValue=nTickValue*10;
   }
//We apply the formula to calculate the position size and assign the value to the variable
   LotSize=(AccountFreeMargin()*(RiskPerTrade/100))/(SL*nTickValue);

   return NormalizeDouble(LotSize, 2);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OpenLongOrder() {
   double stopPips = MathRound((LongEntry - DailyLow + SpreadPrice) * (MathPow(10, _Digits - 1)));

   double stopLoss = LongEntry - (stopPips * SinglePip);
   double lotSize = CalculateLotSize(stopPips);
//Print("Lot Size: ", lotSize);
   int ticket = OrderSend(_Symbol, OP_BUYSTOP, lotSize, LongEntry, 3, stopLoss, 0, NULL, MagicNumber, 0, Green);
   EntrySpreadSprice = SpreadPrice;
   
   if (ticket == -1) {
      MessageBox("ERROR CREATING ORDER: " + (string)GetLastError());
      Print("ERROR CREATING ORDER: " + (string)GetLastError());
      Print("Lot Size: ", lotSize);
      Print("Stop Loss: ", stopPips);
      Print("Ask: ", LongEntry);
   }

   return ticket;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OpenShortOrder() {
   double stopPips = MathRound((DailyHigh + SpreadPrice - ShortEntry) * (MathPow(10, _Digits - 1)));

   double stopLoss = ShortEntry + (stopPips * SinglePip);
   double lotSize = CalculateLotSize(stopPips);

   int ticket = OrderSend(_Symbol, OP_SELLSTOP, lotSize, ShortEntry, 3, stopLoss, 0, NULL, MagicNumber, 0, Green);
   EntrySpreadSprice = SpreadPrice;
   
   if (ticket <= 0) {
      MessageBox("ERROR CREATING ORDER: " + (string)GetLastError());
      Print("ERROR CREATING ORDER: " + (string)GetLastError());
      Print("Lot Size: ", lotSize);
      Print("Stop Loss: ", stopPips);
      Print("Bid: ", ShortEntry);
   }

   return ticket;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SelectOrder() {
   int total=OrdersTotal();
   int ticketNumber = 0;
   
   for(int pos=0; pos<total; pos++) {
      if(!OrderSelect(pos,SELECT_BY_POS)) continue;

      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) {
         ticketNumber = OrderTicket();
         break;
      }
   }
   
   return ticketNumber > 0;
}

void MoveStopLoss() {
   if(!SelectOrder()) {
      MessageBox("No open order for this symbol.", "Order Not Found");
      return;
   }
   
   if(OrderType() == OP_SELL) {
      double stopLoss = OrderOpenPrice() - SinglePip*MoveStopPips;
      if (!OrderModify(OrderTicket(), OrderOpenPrice(), stopLoss, OrderTakeProfit(), OrderExpiration())) {
         MessageBox("Error code: " + (string)GetLastError(), "Error Setting Stop Loss");
      }
   } else if(OrderType() == OP_BUY) {
      double stopLoss = OrderOpenPrice() + SinglePip*MoveStopPips;
      if (!OrderModify(OrderTicket(), OrderOpenPrice(), stopLoss, OrderTakeProfit(), OrderExpiration())) {
         MessageBox("Error code: " + (string)GetLastError(), "Error Setting Stop Loss");
      }
   }
   
}

void SetTrailingStop() {
   if(!SelectOrder()) {
      MessageBox("No open order for this symbol.", "Order Not Found");
      return;
   }
   
   if(ArraySearch(TrailingOrders, OrderTicket()) > -1) {
      MessageBox("Trailing stop already set for this order.", "Trailing Stop");
      return;
   }
   
   ArrayResize(TrailingOrders, ArraySize(TrailingOrders)+1);
   
   double sl = 0;
   
   if(OrderType() == OP_SELL){
      sl = MathRound((OrderStopLoss() - Ask) / SinglePip);
   } else if(OrderType() == OP_BUY) {
      sl = MathRound((Bid - OrderStopLoss()) / SinglePip);
   }
   
   TrailingOrders[ArraySize(TrailingOrders)-1] = new TrailingStop(OrderTicket(), (int)sl);
}

void MoveTrailingStops() {
   for(int i = 0; i<ArraySize(TrailingOrders); i++) {
      if (OrderSelect(TrailingOrders[i].Ticket, SELECT_BY_TICKET)){
         // Order still open
         if (OrderCloseTime() == 0) {
            
            if(OrderType() == OP_SELL){
               double sl = MarketInfo(OrderSymbol(), MODE_ASK) + SinglePip*TrailingOrders[i].Pips;
               if (OrderStopLoss() - sl >= SinglePip) {
                  ModifyStopLoss(sl);
               }
               
            } else if(OrderType() == OP_BUY) {
               double sl = MarketInfo(OrderSymbol(), MODE_BID) - SinglePip*TrailingOrders[i].Pips;
               if (sl - OrderStopLoss() >= SinglePip) {
                  ModifyStopLoss(sl);
               }
            }
         }
      }
   }
}

void ModifyStopLoss(double stopLoss){
   if(!OrderModify(OrderTicket(), OrderOpenPrice(), stopLoss, OrderTakeProfit(), OrderExpiration())) {
      MessageBox("Failed to update trailing stop for order: " + (string)OrderTicket(), "Trailing Stop");
   }
}
int ArraySearch(TrailingStop& array[], int value) {
   for (int i=0; i<ArraySize(array); i++) {
      if (array[i].Ticket == value) return i;
   }
   
   return -1;
}

int ArraySearch(string& array[], string value) {
   for (int i=0; i<ArraySize(array); i++) {
      if (array[i] == value) return i;
   }
   
   return -1;
}

void CloseOrders() {
   if(SelectOrder()) {
      if(OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP) {
         if(!OrderDelete(OrderTicket())) {
            MessageBox("Unable to close order: " + (string)OrderTicket(), "Close Order Failed");
         }
         return;
      }
   
      if(!OrderClose(OrderTicket(), OrderLots(), OrderType() == OP_BUY ? Ask : Bid, 30)) {
         MessageBox("Unable to close order: " + (string)OrderTicket(), "Close Order Failed");
      }
   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam) {

// Buy Stop Clicked
   if(id==CHARTEVENT_OBJECT_CLICK && sparam==_BtnBuyStop) {
      if (ValidLongEntry()) {
         OpenLongOrder();
      } else {
         MessageBox("Can't open long order. Entry conditions not met.", "Invalid Entry");
      }
      
      ObjectSetInteger(0, _BtnBuyStop, OBJPROP_STATE, 0);
   }

// Sell Stop Clicked
   if(id==CHARTEVENT_OBJECT_CLICK && sparam==_BtnSellStop) {
      if (ValidShortEntry()) {
         OpenShortOrder();
      } else {
         MessageBox("Can't open short order. Entry conditions not met.", "Invalid Entry");
      }
      
      ObjectSetInteger(0, _BtnSellStop, OBJPROP_STATE, 0);
   }

// Plus Pip Clicked
   if(id==CHARTEVENT_OBJECT_CLICK && sparam==_BtnPlusPip) {
      MoveStopPips+=1;
      ObjectSetString(0, _BtnMoveToBreakEven, OBJPROP_TEXT, "Move Stop to BE + " + (string)MoveStopPips);
      ObjectSetInteger(0, _BtnPlusPip, OBJPROP_STATE, 0);
   }

// Minus Pip Clicked
   if(id==CHARTEVENT_OBJECT_CLICK && sparam==_BtnMinusPip) {
      MoveStopPips-=1;
      //MoveStopPips = MoveStopPips < 0 ? 0 : MoveStopPips;
      ObjectSetString(0, _BtnMoveToBreakEven, OBJPROP_TEXT, "Move Stop to BE + " + (string)MoveStopPips);
      ObjectSetInteger(0, _BtnMinusPip, OBJPROP_STATE, 0);
   }
   
// Move Stop Loss Clicked
   if(id==CHARTEVENT_OBJECT_CLICK && sparam==_BtnMoveToBreakEven) {
      MoveStopLoss();
      ObjectSetInteger(0, _BtnMoveToBreakEven, OBJPROP_STATE, 0);
   }
   
   // Move Stop Loss Clicked
   if(id==CHARTEVENT_OBJECT_CLICK && sparam==_BtnSetTrailingStop) {
      SetTrailingStop();
      ObjectSetInteger(0, _BtnSetTrailingStop, OBJPROP_STATE, 0);
   }
   
   //Close Orders Clicked
   if(id==CHARTEVENT_OBJECT_CLICK && sparam==_BtnCloseOrder) {
      CloseOrders();
      ObjectSetInteger(0, _BtnCloseOrder, OBJPROP_STATE, 0);
   }

}
//+------------------------------------------------------------------+

void TesterWorkarounds() {
   if( IsVisualMode() )
   {
      long   lparam = 0;
      double dparam = 0.0;
//---
      if( bool( ObjectGetInteger( 0, _BtnSellStop, OBJPROP_STATE ) ) )
        OnChartEvent( CHARTEVENT_OBJECT_CLICK, lparam, dparam, _BtnSellStop );
//---
      if( bool( ObjectGetInteger( 0, _BtnBuyStop, OBJPROP_STATE ) ) )
        OnChartEvent( CHARTEVENT_OBJECT_CLICK, lparam, dparam, _BtnBuyStop );
//---
      if( bool( ObjectGetInteger( 0, _BtnPlusPip, OBJPROP_STATE ) ) )
        OnChartEvent( CHARTEVENT_OBJECT_CLICK, lparam, dparam, _BtnPlusPip );
//---
      if( bool( ObjectGetInteger( 0, _BtnMinusPip, OBJPROP_STATE ) ) )
        OnChartEvent( CHARTEVENT_OBJECT_CLICK, lparam, dparam, _BtnMinusPip );
//---
      if( bool( ObjectGetInteger( 0, _BtnMoveToBreakEven, OBJPROP_STATE ) ) )
        OnChartEvent( CHARTEVENT_OBJECT_CLICK, lparam, dparam, _BtnMoveToBreakEven );
//---
      
      if( bool( ObjectGetInteger( 0, _BtnSetTrailingStop, OBJPROP_STATE ) ) )
        OnChartEvent( CHARTEVENT_OBJECT_CLICK, lparam, dparam, _BtnSetTrailingStop );
//---
      if( bool( ObjectGetInteger( 0, _BtnCloseOrder, OBJPROP_STATE ) ) )
        OnChartEvent( CHARTEVENT_OBJECT_CLICK, lparam, dparam, _BtnCloseOrder );
//---
      for(int i=0; i<TesterSpeed; i++) {Comment("Wait Loop Count = ", i);}
   }
}


void ShowAlert(string symbol, datetime time, string message) {
   if (!ShowAlerts) return;
   
   string id = symbol+(string)time+message;
   if(ArraySearch(Alerts, id) < 0) {
      ArrayResize(Alerts, ArraySize(Alerts)+1);
      Alerts[ArraySize(Alerts)-1] = id;
      Alert(symbol + "  -  ", time + "  -  ", message);
   }
}


void DrawEmotionLabels() {
   if (!ShowMotivationalMessage) return;
   
   DrawLabel(_LblEmotions + "1", "Follow the rules", clrCornflowerBlue, 16, 20, 400, CORNER_RIGHT_UPPER, "Arial Bold");
   DrawLabel(_LblEmotions + "2", "Stick to the plan", clrCornflowerBlue, 16, 20, 430, CORNER_RIGHT_UPPER, "Arial Bold");
   DrawLabel(_LblEmotions + "3", "Everything will be fine :)", clrCornflowerBlue, 16, 20, 460, CORNER_RIGHT_UPPER, "Arial Bold");
}

void DeleteEmotionLabels() {
   ObjectDelete(_LblEmotions + "1");
   ObjectDelete(_LblEmotions + "2");
   ObjectDelete(_LblEmotions + "3");
}