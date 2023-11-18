## daily-bias-testing

Little python script for backtesting TTrades' daily bias model.

YT video explaining the model: https://youtu.be/g3oDYq4P9ZE

#### Variation of the model backtested here

In order to produce a deterministic outcome in all circumstances, the model tested here is as follows:

- If the candle for date _d_ is an outside bar, then bias is up if the close is above the midpoint of the daily range (high-low) for _d_, and down otherwise
- If the candle for date _d_ is an inside bar, then bias is up if the close is above the midpoint of the daily range (high-low) for _d-1_, and down otherwise
- Bias is up if the candle for date _d_ has both a high and close above the high of candle _d-1_
- Bias is down if the candle for date _d_ has both a low and close below the low of candle _d-1_
- Bias is up if the candle for date _d_ has a low below the low of candle _d-1_ but a close within the range of _d-1_ (sweeps the low and closes back within the range)
- Bias is down if the candle for date _d_ has a high above the high of candle _d-1_ but a close within the range of _d-1_ (sweeps the high and closes back within the range)

Note that items 1 and 2 are variations on TTrades' original model.

#### Obtaining data

Open a daily (D1) chart for the instrument you want to test, scroll back to the beginning of the series, and export the chart data. Check the
`testing.py` script for expected file names (and change as necessary).

#### Running the test

Assuming you've put the data in `/opt/data/` locally:

```
docker build -t daily-bias-testing .
docker run -it --rm --mount type=bind,source=/opt/data/,target=/opt/data/,ro daily-bias-testing
```
