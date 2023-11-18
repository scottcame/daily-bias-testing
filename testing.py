import pandas as pd
import numpy as np
from datetime import timedelta
import re

ohlc = '/opt/data/ES_D1_1998_2023.csv'
# ohlc = '/opt/data/YM_D1_2002_2023.csv'
# ohlc = '/opt/data/NQ_D1_1999_2023.csv'
# ohlc = '/opt/data/RTY_D1_2017_2023.csv'

ohlc = pd.read_csv(ohlc, parse_dates=['time'],
    dtype={'time': 'str','open': 'float','high': 'float','low': 'float','close': 'float','Volume': 'float','Volume MA': 'float'})

# convert time field and add one day (just because of the way TradingView exports data)
ohlc['time'] = pd.to_datetime(ohlc['time'], utc=True)
ohlc['time'] = ohlc['time'] + timedelta(days=1)

# drop first row (no lag) and last row (potentially incomplete)
ohlc = ohlc.drop(index=[0, len(ohlc)-1])

ohlc['date'] = ohlc['time'].dt.date
ohlc = ohlc.set_index('time')

# don't need these volume columns
ohlc = ohlc.drop(columns=['Volume','Volume MA'])

# uncomment to resample to weekly
# ohlc = ohlc.resample('W-Fri').last()

ohlc = ohlc.set_index('date')

ohlc['highLag'] = ohlc['high'].shift(1)
ohlc['lowLag'] = ohlc['low'].shift(1)

def is_inside(row):
    return row['high'] < row['highLag'] and row['low'] > row['lowLag']

def is_outside(row):
    return row['low'] < row['lowLag'] and row['high'] > row['highLag']

def is_sweep(row):
    return (row['high'] > row['highLag'] and row['close'] < row['highLag']) or (row['low'] < row['lowLag'] and row['close'] > row['lowLag'])

def compute_bias(row):
    if is_outside(row):
        if row['close'] > row['low'] + (row['high'] - row['low']) / 2:
            return 'up'
        else:
            return 'down'
    elif is_inside(row):
        rangeMidpoint = row['lowLag'] + (row['highLag'] - row['lowLag'])/2
        if row['close'] > rangeMidpoint:
            return 'up'
        else:
            return 'down'
    elif is_sweep(row):
        if row['close'] < row['high']:
            return 'down'
        else:
            return 'up'
    else:
        if row['close'] > row['lowLag']:
            return 'up'
        else:
            return 'down'
        
ohlc['bias'] = ohlc.apply(compute_bias, axis=1)
ohlc['biasLag'] = ohlc['bias'].shift(1)
ohlc['inside'] = ohlc.apply(is_inside, axis=1)
ohlc['outside'] = ohlc.apply(is_outside, axis=1)
ohlc['sweep'] = ohlc.apply(is_sweep, axis=1)

def compute_result(row):
    if is_outside(row):
        return 'outside'
    elif row['low'] < row['lowLag']:
        return 'down'
    elif row['high'] > row['highLag']:
        return 'up'
    elif row['close'] > row['open']:
        return 'up'
    else:
        return 'down'
    
ohlc['result'] = ohlc.apply(compute_result, axis=1)

ohlc = ohlc.drop(columns=[col for col in ohlc.columns if col.endswith('Lag')])

print(ohlc.tail(50))

print("correct bias percentage: {:.2f}%".format(100*((ohlc['result']==ohlc['bias']) | (ohlc['result']=='outside')).sum() / len(ohlc)))
print("inside bars: {:.2f}%".format(100*ohlc['inside'].sum() / len(ohlc)))
print("outside bars: {:.2f}%".format(100*ohlc['outside'].sum() / len(ohlc)))
print("sweep reversal bars: {:.2f}%".format(100*ohlc['sweep'].sum() / len(ohlc)))
