library(tidyverse)
library(lubridate)

options(pillar.sigfig=8)

rawDf <- read_csv('/opt/data/NQ_D1_1999_2024.csv') %>%
  mutate(d=as_date(time)) %>% select(d, open, high, low, close)

tdf <- rawDf %>%
  mutate(
    outside=high >= lag(high) & low <= lag(low),
    inside=high <= lag(high) & low >= lag(low),
    sweepHigh=high > lag(high) & close < lag(high),
    sweepLow=low < lag(low) & close > lag(low),
    sweep=sweepHigh | sweepLow,
    closeType=case_when(close > open ~ 'up', close < open ~ 'down', .default = 'flat'),
    upperWick=if_else(high==low, NA_real_, (high-pmax(open, close)) / (high-low)),
    lowerWick=if_else(high==low, NA_real_, (pmin(open, close)-low) / (high-low)),
    body=if_else(high==low, NA_real_, (abs(open-close)) / (high-low)),
    spinningTop=body < .2 & abs(upperWick-lowerWick) < .1
  ) %>% mutate(
    bias=case_when(
      inside ~ if_else(closeType=='up', 'up', 'down'),
      close >= lag(high) ~ 'up',
      close <= lag(low) ~ 'down',
      sweepHigh ~ 'down',
      sweepLow ~ 'up',
      .default=NA_character_
    )
  ) %>% filter(row_number() != 1) %>% mutate(
    biasResult = (bias=='up' & high <= lead(high)) | (bias=='down' & low >= lead(low))
  ) %>% filter(row_number() != n())
