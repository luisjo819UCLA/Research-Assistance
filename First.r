# Assuming the necessary libraries are installed
library(data.table)
library(survival) # For survival analysis, might need adaptations for Tobit models
library(censReg)  # For Tobit regression
library(dplyr)
library(tidyverse)
library(lubridate)  # For easy date handling

library(haven) # For reading Stata files

#Lets see all the dta files that are in the folder SIEED_7518_v1_test
dta_files = list.files("SIEED_7518_v1_test", pattern = ".dta")

#Lets read the dta files and store them in a list
dta_list = lapply(dta_files, function(x) read_dta(paste0("SIEED_7518_v1_test/", x)))
class(dta_list)
length(dta_list)

#Lets see the head of the dta_list
for (i in 1:length(dta_list)){
  print(dta_files[i])
  print(head(dta_list[[i]],1))
}

for (i in 1:length(dta_list)){
    names(dta_list[[i]]) %>%
    str_detect("gebjahr") %>%
    any() %>%
    print()
}

#I think its using the last one!
dta_list[[50]] %>%
  head()
