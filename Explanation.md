RA Luis Zapata - PHD Luca - Anderson School of Economics
================

## Explanation of Code

I will be utilizing matched employer-employee data from Germany. In this
[link](https://fdz.iab.de/en/int_bd_pd/the-sample-of-integrated-employer-employee-data-sieed-sieed-7518-version-1/),
you can find a description of the dataset. Specifically, there is a file
at the link containing a detailed description of the data
([this](https://doku.iab.de/fdz/reporte/2020/DR_14-20_EN.pdf)) and the
test data, which is a fake data. Unfortunately, access to the real data
is restricted due to confidentiality constraints associated with the
dataset.

This [paper](https://davidcard.berkeley.edu/papers/QJE-2013.pdf) is an
excellent piece that utilizes the same dataset, implementing certain
methodologies and approaches that I aim to replicate or use as a
foundation for my analysis. Additionally, the paper discusses some
issues with the dataset, including the fact that wages are capped. When
wages exceed a specific threshold, they are recorded as the threshold
value. The authors employ a methodology to estimate the actual wage
beyond the threshold, and I plan to adopt a similar approach. The
initial task will involve replicating their code, translating it into
either R.

## Preparing the Data

We beggin by calling the libraries as follow:

``` r
library(data.table) #Table data handler
library(censReg)  # For Tobit regression
library(dplyr) #Also data handler
library(tidyverse) #For data managment
library(lubridate)  # For easy date handling
library(haven) # For reading Stata files
```

## Including Plots

You can also embed plots, for example:

``` r
dta_files = list.files("SIEED_7518_v1_test", pattern = ".dta")
dta_list = lapply(dta_files, function(x) read_dta(paste0("SIEED_7518_v1_test/", x)))
print(class(dta_list))
```

    ## [1] "list"

Note that the `echo = FALSE` parameter was added to the code chunk to
prevent printing of the R code that generated the plot.
