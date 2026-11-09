# Forex Sessions & Pivots

A MetaTrader 5 indicator that draws, on the price chart:

- **Session boxes** for Tokyo, London and New York, covering each session's high and low, on H1 and lower. London and New York follow their own daylight saving dates.
- **Daily pivot points** (pivot, R1, R2, S1, S2) from the previous trading day, on charts below D1.

## Install

1. In MetaEditor, open `ForexSessionsPivots.mq5` and press Compile.
2. Copy `ForexSessionsPivots.ex5` to your terminal's `MQL5/Indicators` folder (File > Open Data Folder in MT5).
3. In MT5, refresh the Navigator and drag the indicator onto a chart.

## Settings

| Setting | Default | Meaning |
| --- | --- | --- |
| Show session boxes | on | Boxes are hidden above H1 either way |
| Days of sessions to draw | 20 | How far back boxes go |
| Show session names | on | Name above each box |
| Session colours | dark tones | One colour for each city |
| Server GMT offset | 0 | 0 detects it from the broker's clock; otherwise enter the hours |
| Server follows US daylight saving | on | Keeps older boxes aligned for brokers whose clock moves with New York |

If boxes on older dates sit an hour off, your broker's clock does not follow US daylight saving, so turn that setting off.
