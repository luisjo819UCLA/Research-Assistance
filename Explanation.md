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
library(tidyverse,quietly = TRUE) #For data managment
library(lubridate)  # For easy date handling
library(haven) # For reading Stata files
```

## Call the data

We call the Stata data (.dta) from our folder and store it in a list.

``` r
dta_files = list.files("SIEED_7518_v1_test", pattern = ".dta")
dta_list = lapply(dta_files, function(x) read_dta(paste0("SIEED_7518_v1_test/", x)))
print(class(dta_list))
```

    ## [1] "list"

I now print the last 10 rows of the list to see what kind of data we are
dealing with.

``` r
print(tail(dta_files, 10))
```

    ##  [1] "SIEED_7518_v1_bhp_2015_v1.dta"    "SIEED_7518_v1_bhp_2016_v1.dta"   
    ##  [3] "SIEED_7518_v1_bhp_2017_v1.dta"    "SIEED_7518_v1_bhp_2018_v1.dta"   
    ##  [5] "SIEED_7518_v1_bhp_basis_v1.dta"   "SIEED_7518_v1_bhp_entry_v1.dta"  
    ##  [7] "SIEED_7518_v1_bhp_exit_v1.dta"    "SIEED_7518_v1_bhp_inflow_v1.dta" 
    ##  [9] "SIEED_7518_v1_bhp_outflow_v1.dta" "SIEED_7518_v1.dta"

We can see that the data have one kind related with years, while the
others have the names: basis, entry, exit, infow and outflow associated
with them.

``` r
#On dta_files there are data with year on the name, and other without it.
#Lets filter the ones with year on the name

dta_files_2 <- dta_files[str_detect(dta_files, "^(SIEED_7518_v1_bhp_20|SIEED_7518_v1_bhp_19)")]

dta_files_3 <- dta_files[!dta_files %in% dta_files_2]

print(dta_files_3)
```

    ## [1] "SIEED_7518_v1_bhp_basis_v1.dta"   "SIEED_7518_v1_bhp_entry_v1.dta"  
    ## [3] "SIEED_7518_v1_bhp_exit_v1.dta"    "SIEED_7518_v1_bhp_inflow_v1.dta" 
    ## [5] "SIEED_7518_v1_bhp_outflow_v1.dta" "SIEED_7518_v1.dta"

We know merge all the data that are related with the yeards 2019 and
2020.

``` r
dta_year = tibble("Address" = dta_files_2) %>%
  mutate("Year" = str_sub(Address, start = 19, end = 22))
#We extract the year, wich is the second four digits of the file name
#Lets read all the dta in the Address column and store them in a list. Lets name the list with the year of the data
dta_list_2 = lapply(dta_files_2, function(x) read_dta(paste0("SIEED_7518_v1_test/", x)))
names(dta_list_2) = dta_year$Year
#Lets merge all the data in dta_list_2, in order to create one big tibble. We also create one column with name "Year" to store the year of the data
dta_list_2 = dta_list_2 %>%
  bind_rows(.id = "Year") %>%
  select(-Year)
print(paste("The size of the data is: rows:", nrow(dta_list_2), " and columns:", ncol(dta_list_2)))
```

    ## [1] "The size of the data is: rows: 197898  and columns: 10"

``` r
print(head(dta_list_2,3))
```

    ## # A tibble: 3 × 10
    ##   betnr      jahr az_f    az_reg az_azubi az_atz az_tz az_f_vz az_f_tz az_reg_vz
    ##   <dbl+lbl> <dbl> <dbl+l> <dbl+> <dbl+lb> <dbl+> <dbl> <dbl+l> <dbl+l> <dbl+lbl>
    ## 1 49914458   1975  4        9    3        0      0      3      0         9      
    ## 2 49916216   1975 60      155    1        0      0     59      0       155      
    ## 3 49916399   1975  7      255    2        0      3      5      2       252

``` r
print(glimpse(dta_list_2))
```

    ## Rows: 197,898
    ## Columns: 10
    ## $ betnr     <dbl+lbl> 49914458, 49916216, 49916399, 49916406, 49916493, 499178…
    ## $ jahr      <dbl> 1975, 1975, 1975, 1975, 1975, 1975, 1975, 1975, 1975, 1975, …
    ## $ az_f      <dbl+lbl>   4,  60,   7,   4,   0,  28,  10,  96,   1,   2,   4,  …
    ## $ az_reg    <dbl+lbl>    9,  155,  255,    3,    3,   53,  114,  154,    1,   …
    ## $ az_azubi  <dbl+lbl>  3,  1,  2,  1,  0,  2, 18,  3,  0,  0,  0,  0, 28,  0, …
    ## $ az_atz    <dbl+lbl> 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,…
    ## $ az_tz     <dbl+lbl>  0,  0,  3,  2,  0, 11,  5,  1,  0,  0,  1,  0, 50,  0, …
    ## $ az_f_vz   <dbl+lbl>   3,  59,   5,   1,   0,  16,   4,  93,   1,   2,   3,  …
    ## $ az_f_tz   <dbl+lbl>  0,  0,  2,  2,  0, 10,  5,  1,  0,  0,  1,  0, 50,  0, …
    ## $ az_reg_vz <dbl+lbl>   9, 155, 252,   1,   3,  42, 109, 153,   1,   2,   6,  …
    ## # A tibble: 197,898 × 10
    ##    betnr      jahr az_f   az_reg az_azubi az_atz az_tz az_f_vz az_f_tz az_reg_vz
    ##    <dbl+lbl> <dbl> <dbl+> <dbl+> <dbl+lb> <dbl+> <dbl> <dbl+l> <dbl+l> <dbl+lbl>
    ##  1 49914458   1975  4       9     3       0       0     3       0        9      
    ##  2 49916216   1975 60     155     1       0       0    59       0      155      
    ##  3 49916399   1975  7     255     2       0       3     5       2      252      
    ##  4 49916406   1975  4       3     1       0       2     1       2        1      
    ##  5 49916493   1975  0       3     0       0       0     0       0        3      
    ##  6 49917890   1975 28      53     2       0      11    16      10       42      
    ##  7 49918306   1975 10     114    18       0       5     4       5      109      
    ##  8 49918999   1975 96     154     3       0       1    93       1      153      
    ##  9 49919426   1975  1       1     0       0       0     1       0        1      
    ## 10 49919628   1975  2       2     0       0       0     2       0        2      
    ## # ℹ 197,888 more rows

We still have to understand better the way the data is gathered. We have
to read the documentation in order to do it.

``` r
print(dta_files_3)
```

    ## [1] "SIEED_7518_v1_bhp_basis_v1.dta"   "SIEED_7518_v1_bhp_entry_v1.dta"  
    ## [3] "SIEED_7518_v1_bhp_exit_v1.dta"    "SIEED_7518_v1_bhp_inflow_v1.dta" 
    ## [5] "SIEED_7518_v1_bhp_outflow_v1.dta" "SIEED_7518_v1.dta"
