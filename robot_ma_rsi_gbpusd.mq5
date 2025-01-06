//+------------------------------------------------------------------+
//|                                               robot_ma_rsi_gbpusd.mq5 |
//|                                             Adapted for GBPUSD Trading |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version   "1.00"

enum ESTRATEGIA_ENTRADA
  {
   APENAS_MM,  // Moving Averages Only
   APENAS_RSI, // RSI Only
   MM_E_RSI    // Moving Averages and RSI
  };

// Input Parameters
input string s0; //-----------Entry Strategy-------------
input ESTRATEGIA_ENTRADA   estrategia      = APENAS_MM;     // Trading Entry Strategy

input string s1; //-----------Moving Averages-------------
input int mm_rapida_periodo                = 12;            // Fast MA Period
input int mm_lenta_periodo                 = 32;            // Slow MA Period
input ENUM_TIMEFRAMES mm_tempo_grafico     = PERIOD_CURRENT;// Timeframe
input ENUM_MA_METHOD  mm_metodo            = MODE_EMA;      // Method
input ENUM_APPLIED_PRICE  mm_preco         = PRICE_CLOSE;   // Applied Price

input string s2; //-----------RSI-------------
input int rsi_periodo                      = 5;             // RSI Period
input ENUM_TIMEFRAMES rsi_tempo_grafico    = PERIOD_CURRENT;// Timeframe
input ENUM_APPLIED_PRICE rsi_preco         = PRICE_CLOSE;   // Applied Price

input int rsi_sobrecompra                  = 70;            // Overbought Level
input int rsi_sobrevenda                   = 30;            // Oversold Level

input string s3; //---------------------------
input int num_lots                         = 100;           // Number of Lots
input double TK                            = 60;            // Take Profit (pips)
input double SL                            = 30;            // Stop Loss (pips)

input string s4; //---------------------------
input string hora_limite_fecha_op          = "17:40";       // Position Close Time Limit

// Indicator Variables
int mm_rapida_Handle;     
double mm_rapida_Buffer[];

int mm_lenta_Handle;      
double mm_lenta_Buffer[]; 

int rsi_Handle;          
double rsi_Buffer[];     

// Trading Variables
int magic_number = 234567;   // Magic Number for GBPUSD
MqlRates velas[];           
MqlTick tick;               

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    mm_rapida_Handle = iMA("GBPUSD", mm_tempo_grafico, mm_rapida_periodo, 0, mm_metodo, mm_preco);
    mm_lenta_Handle  = iMA("GBPUSD", mm_tempo_grafico, mm_lenta_periodo, 0, mm_metodo, mm_preco);
    rsi_Handle = iRSI("GBPUSD", rsi_tempo_grafico, rsi_periodo, rsi_preco);
    
    if(mm_rapida_Handle<0 || mm_lenta_Handle<0 || rsi_Handle<0)
    {
        Alert("Error creating indicator handles - error: ", GetLastError());
        return(-1);
    }
    
    CopyRates("GBPUSD", _Period, 0, 4, velas);
    ArraySetAsSeries(velas, true);
    
    ChartIndicatorAdd(0, 0, mm_rapida_Handle); 
    ChartIndicatorAdd(0, 0, mm_lenta_Handle);
    ChartIndicatorAdd(0, 1, rsi_Handle);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    IndicatorRelease(mm_rapida_Handle);
    IndicatorRelease(mm_lenta_Handle);
    IndicatorRelease(rsi_Handle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
    CopyBuffer(mm_rapida_Handle, 0, 0, 4, mm_rapida_Buffer);
    CopyBuffer(mm_lenta_Handle, 0, 0, 4, mm_lenta_Buffer);
    CopyBuffer(rsi_Handle, 0, 0, 4, rsi_Buffer);
    
    CopyRates("GBPUSD", _Period, 0, 4, velas);
    ArraySetAsSeries(velas, true);
    
    ArraySetAsSeries(mm_rapida_Buffer, true);
    ArraySetAsSeries(mm_lenta_Buffer, true);
    ArraySetAsSeries(rsi_Buffer, true);
    
    SymbolInfoTick("GBPUSD", tick);
   
    // BUY LOGIC
    bool compra_mm_cros = mm_rapida_Buffer[0] > mm_lenta_Buffer[0] &&
                         mm_rapida_Buffer[2] < mm_lenta_Buffer[2];
                                             
    bool compra_rsi = rsi_Buffer[0] <= rsi_sobrevenda;
    
    // SELL LOGIC
    bool venda_mm_cros = mm_lenta_Buffer[0] > mm_rapida_Buffer[0] &&
                        mm_lenta_Buffer[2] < mm_rapida_Buffer[2];
    
    bool venda_rsi = rsi_Buffer[0] >= rsi_sobrecompra;
   
    bool Comprar = false;
    bool Vender  = false;
    
    if(estrategia == APENAS_MM)
    {
        Comprar = compra_mm_cros;
        Vender  = venda_mm_cros;
    }
    else if(estrategia == APENAS_RSI)
    {
        Comprar = compra_rsi;
        Vender  = venda_rsi;
    }
    else
    {
        Comprar = compra_mm_cros && compra_rsi;
        Vender  = venda_mm_cros && venda_rsi;
    } 
   
    bool temosNovaVela = TemosNovaVela(); 
    
    if(temosNovaVela)
    {
        if(Comprar && PositionSelect("GBPUSD")==false)
        {
            desenhaLinhaVertical("Compra", velas[1].time, clrBlue);
            CompraAMercado();
        }
       
        if(Vender && PositionSelect("GBPUSD")==false)
        {
            desenhaLinhaVertical("Venda", velas[1].time, clrRed);
            VendaAMercado();
        } 
    }
    
    if(TimeToString(TimeCurrent(),TIME_MINUTES) == hora_limite_fecha_op && PositionSelect("GBPUSD")==true)
    {
        Print("-----> End of Operational Time: closing open positions!");
             
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
            FechaCompra();
        }
        else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
            FechaVenda();
        }
    }  
}

//+------------------------------------------------------------------+
//| VISUALIZATION HELPER FUNCTIONS                                     |
//+------------------------------------------------------------------+
void desenhaLinhaVertical(string nome, datetime dt, color cor = clrBlueViolet)
{
    ObjectDelete(0, nome);
    ObjectCreate(0, nome, OBJ_VLINE, 0, dt, 0);
    ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
}

//+------------------------------------------------------------------+
//| ORDER FUNCTIONS                                                    |
//+------------------------------------------------------------------+
void CompraAMercado()
{
    MqlTradeRequest request = {};
    MqlTradeResult  result = {};
   
    request.action       = TRADE_ACTION_DEAL;
    request.magic        = magic_number;
    request.symbol       = "GBPUSD";
    request.volume       = num_lots;
    request.price        = NormalizeDouble(tick.ask, _Digits);
    request.sl           = NormalizeDouble(tick.ask - SL*_Point, _Digits);
    request.tp           = NormalizeDouble(tick.ask + TK*_Point, _Digits);
    request.deviation    = 0;
    request.type         = ORDER_TYPE_BUY;
    request.type_filling = ORDER_FILLING_FOK;
   
    bool success = OrderSend(request, result);
   
    if(result.retcode == 10008 || result.retcode == 10009)
    {
        Print("Buy order executed successfully!");
    }
    else
    {
        Print("Error sending Buy order. Error = ", GetLastError());
        ResetLastError();
    }
}

void VendaAMercado()
{
    MqlTradeRequest request = {};
    MqlTradeResult  result = {};
   
    request.action       = TRADE_ACTION_DEAL;
    request.magic        = magic_number;
    request.symbol       = "GBPUSD";
    request.volume       = num_lots;
    request.price        = NormalizeDouble(tick.bid, _Digits);
    request.sl           = NormalizeDouble(tick.bid + SL*_Point, _Digits);
    request.tp           = NormalizeDouble(tick.bid - TK*_Point, _Digits);
    request.deviation    = 0;
    request.type         = ORDER_TYPE_SELL;
    request.type_filling = ORDER_FILLING_FOK;
   
    bool success = OrderSend(request, result);
   
    if(result.retcode == 10008 || result.retcode == 10009)
    {
        Print("Sell order executed successfully!");
    }
    else
    {
        Print("Error sending Sell order. Error = ", GetLastError());
        ResetLastError();
    }
}

void FechaCompra()
{
    MqlTradeRequest request = {};
    MqlTradeResult  result = {};
      
    request.action       = TRADE_ACTION_DEAL;
    request.magic        = magic_number;
    request.symbol       = "GBPUSD";
    request.volume       = num_lots;
    request.price        = 0;
    request.type         = ORDER_TYPE_SELL;
    request.type_filling = ORDER_FILLING_RETURN;
      
    bool success = OrderSend(request, result);
      
    if(result.retcode == 10008 || result.retcode == 10009)
    {
        Print("Position closed successfully!");
    }
    else
    {
        Print("Error closing position. Error = ", GetLastError());
        ResetLastError();
    }
}

void FechaVenda()
{
    MqlTradeRequest request = {};
    MqlTradeResult  result = {};
      
    request.action       = TRADE_ACTION_DEAL;
    request.magic        = magic_number;
    request.symbol       = "GBPUSD";
    request.volume       = num_lots;
    request.price        = 0;
    request.type         = ORDER_TYPE_BUY;
    request.type_filling = ORDER_FILLING_RETURN;
      
    bool success = OrderSend(request, result);
   
    if(result.retcode == 10008 || result.retcode == 10009)
    {
        Print("Position closed successfully!");
    }
    else
    {
        Print("Error closing position. Error = ", GetLastError());
        ResetLastError();
    }
}

//+------------------------------------------------------------------+
//| UTILITY FUNCTIONS                                                  |
//+------------------------------------------------------------------+
bool TemosNovaVela()
{
    static datetime last_time = 0;
    datetime lastbar_time = (datetime)SeriesInfoInteger("GBPUSD", Period(), SERIES_LASTBAR_DATE);

    if(last_time == 0)
    {
        last_time = lastbar_time;
        return false;
    }

    if(last_time != lastbar_time)
    {
        last_time = lastbar_time;
        return true;
    }
    return false;
}