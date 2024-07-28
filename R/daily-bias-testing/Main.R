library(tidyverse)
library(lubridate)
library(tidyquant)
library(caret)
library(nnet)

options(pillar.sigfig=8)

DATA='/opt/data/NQ_D1_1999_2024.csv'
# DATA='/opt/data/NQ_W1_1999_2024.csv'
# DATA='/opt/data/GC_D1_1999_2024.csv'

rawDf <- read_csv(DATA) %>%
  mutate(d=as_date(time)) %>% select(d, open, high, low, close)

tdf <- rawDf %>%
  mutate(
    outside=high >= lag(high) & low <= lag(low),
    inside=high <= lag(high) & low >= lag(low),
    sweepHigh=high > lag(high) & close < lag(high),
    sweepLow=low < lag(low) & close > lag(low),
    sweep=sweepHigh | sweepLow,
    hlRange=high-low,
    closeType=case_when(close > open ~ 'up', close < open ~ 'down', .default = 'flat'),
    upperWick=if_else(high==low, NA_real_, (high-pmax(open, close)) / (hlRange)),
    lowerWick=if_else(high==low, NA_real_, (pmin(open, close)-low) / (hlRange)),
    body=if_else(high==low, NA_real_, (abs(open-close)) / (hlRange)),
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
  ) %>% tq_mutate(
    select=hlRange, mutate_fun = SMA, n=10, col_rename=c('SMA'='ADR')
  ) %>% filter(row_number() != 1) %>% mutate(
    result=case_when(
      high <= lead(high) & low >= lead(low) ~ 'outside',
      high <= lead(high) ~ 'up',
      low >= lead(low) ~ 'down',
      .default = 'inside'
    ),
    win = (bias=='up' & high <= lead(high)) | (bias=='down' & low >= lead(low)),
    lose = (bias=='up' & high > lead(high) & low > lead(low)) | (bias=='down' & low < lead(low) & high < lead(high)),
    volatile = hlRange > ADR,
    biasSideWickAdrPct=(if_else(bias=='up', upperWick, lowerWick) * hlRange / ADR)
  ) %>% filter(row_number() != n())

# main winrate analysis

tdf %>% group_by(inside, outside, sweep, spinningTop) %>% summarize(winrate=mean(win), cnt=n()) %>% arrange(desc(winrate)) %>% filter(cnt > 1) %>% print(n=50)
tdf %>% group_by(inside, outside, sweep, spinningTop) %>% summarize(loserate=mean(lose), cnt=n()) %>% arrange(desc(loserate)) %>% filter(cnt > 1) %>% print(n=50)

# winrate by year

tdf %>% mutate(y=year(d)) %>% group_by(y) %>% summarize(winrate=mean(win), cnt=n()) %>% arrange(y) %>% print(n=50)

# logistic regression of win
model <- glm(win ~ biasSideWickAdrPct + sweep + outside + inside + spinningTop, data = tdf, family = binomial)

# multinomial logistic regression of result
model <- multinom(result ~ biasSideWickAdrPct + sweep + outside + inside + spinningTop, data = tdf %>% mutate(result=relevel(as.factor(result), ref='inside')))
summary(model)
z <- summary(model)$coefficients/summary(model)$standard.errors
p <- (1 - pnorm(abs(z), 0, 1)) * 2
p

predicted_classes <- predict(model, newdata = tdf)

