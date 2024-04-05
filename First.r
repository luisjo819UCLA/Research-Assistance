# Assuming the necessary libraries are installed
library(data.table)
library(survival) # For survival analysis, might need adaptations for Tobit models
library(censReg)  # For Tobit regression
library(dplyr) # For data manipulation
library(tidyverse) # For data manipulation
library(lubridate)  # For easy date handling
library(haven) # For reading Stata files

#Lets see all the dta files that are in the folder SIEED_7518_v1_test
dta_files = list.files("SIEED_7518_v1_test", pattern = ".dta")

#Lets read the dta files and store them in a list
dta_list = lapply(dta_files, function(x) read_dta(paste0("SIEED_7518_v1_test/", x)))
library(labelled)

#q: How can i read the labels of the data using labelled?
#A: You can use the argument label = TRUE in the read_dta function

dta_list[[1]] %>% 
  look_for()

library(readstata13)
dta_label2 = lapply(dta_files, function(x) read.dta13(paste0("SIEED_7518_v1_test/", x)))

dta_label2[[2]] %>% 
  class()
dta_label2 = lapply(dta_label2, function(x) x %>% set.lang("en"))
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

print(dta_files)
#On dta_files there are data with year on the name, and other without it. Lets filter the ones with year on the name
dta_files_2 = dta_files[str_detect(dta_files, "^(SIEED_7518_v1_bhp_20|SIEED_7518_v1_bhp_19)")]

dta_files_3 = dta_files[!dta_files %in% dta_files_2]

print(dta_files_3) 

dta_year = tibble("Address" = dta_files_2) %>%
  mutate("Year" = str_sub(Address, start = 19, end = 22))

#We extract the year, wich is the second four digits of the file name
#Lets read all the dta in the Address column and store them in a list. Lets name the list with the year of the data
dta_list_2 = lapply(dta_files_2, function(x) read_dta(paste0("SIEED_7518_v1_test/", x)))

names(dta_list_2) = dta_year$Year
#Lets merge all the data in dta_list_2, in order to create one big tibble. We also create one column with name "Year" to store the year of the data
dta_list_3 = dta_list_2 %>%
  bind_rows(.id = "Year") %>%
  select(-Year)

names(dta_list_3)

#Lets read all the adress inside dta_files_3 and store them in a list
dta_list_4 = lapply(dta_files_3, function(x) read_dta(paste0("SIEED_7518_v1_test/", x)))

#Lets print the names of every data in dta_list_4
for (i in 1:length(dta_list_4)){
  print(dta_files_3[i])
  print(names(dta_list_4[[i]]))
}


library(readstata13)
#Individual
ind = read.dta13("SIEED_7518_v1_test/SIEED_7518_v1.dta") %>% 
  set.lang("en")
ind %>% attributes() %>% names()
ind_label = ind %>%
  attr("var.labels")
for (i in 1:length(ind_label)){
  ind = ind %>% set_variable_labels(!!names(ind)[i] := ind_label[[i]])
}
#Business. Basis
basis = read.dta13("SIEED_7518_v1_test/SIEED_7518_v1_bhp_basis_v1.dta") %>% 
  set.lang("en")

bas_label = basis %>%
  attr("var.labels")
for (i in 1:length(bas_label)){
  basis = basis %>% set_variable_labels(!!names(basis)[i] := bas_label[[i]])
}
#q: How to transform ind to a tibble with the labels?
#A: You can use the labelled package to transform the data to a tibble with the labels

#Transforming ind to tibble with labels

#Lets merge ind and basis. We merge by jahr, which is the year of the data, and by betnr, which is the business number
ind_basis = ind %>%
  mutate(jahr = year(begepi)) %>% 
  left_join(basis, by = c("jahr", "betnr"))


cat("IAB data - men age 20-60 - full time, excl marginals\n")
#### Rename ####
ind2 = ind_basis %>% rename(
  id = persnr,
  firmid = betnr,
  birthyr = gebjahr,
  education = schule,
  dailywage = tentgelt,
  occupation = beruf,
  year = jahr,
  female = frau,
  federal_state = ao_bula,
  occupation_status_hrs = stib,
  emp_status = erwstat,
  begin_date = begorig,
  end_date = endorig,
  sic_code1 = w73_3,
  sic_code2 = w93_3,
  sic_code3 = w03_3
)
#Lets split federal_state into two columns, one with the number and the other with the name, using Regex
ind2 = ind2 %>%
  mutate(federal_state_number = str_extract(federal_state, "\\d+") %>% as.numeric(), #Extract the number of the federal state
         federal_state_name = str_extract(federal_state, "\\D+")) %>% #Extract the name of the federal state
  mutate(occupation_status_hrs_number = str_extract(occupation_status_hrs, "\\d+") %>% as.numeric(), #Extract the number of the occupation status
         occupation_status_hrs_name = str_extract(occupation_status_hrs, "\\D+")) #Extract the name of the occupation status (half time, unskilled, employee, home worker, etc.)
#Lets see how much female nd male we have
ind2$female %>% table()
#Daily Wage
ind2$dailywage %>% summary()
ind2$occupation_status_hrs %>% summary()
ind2$firmid %>% summary()
#Filter
ind2 = ind2 %>%
  filter(!is.na(firmid), # no missings
         female == '0 Male', #only males
         federal_state_number >= 1 & federal_state_number <= 11, # Eliminate jobs out of the range 1-11 for federal_state
         begin_date < dmy('01-01-2010'), # Beging Date before January 1, 2010
         dailywage >= 1, # drop daily wage (in current euro) of less than 1 -- siab standard
         !emp_status %in% c("109 Marginal part-time workers",
                         110, 
                         202, 
                         "209 Marginal part-time workers (household cheque)", 
                         210), # drop marginal employment
           occupation_status_hrs_number >= 0 & occupation_status_hrs_number <= 4) #Between vocational training, unskilled worker, skilled worker, blue/white collar and full-time employment
         
ind2$education %>% unique()


ind2 = ind2 %>% 
  mutate(trainee = (year < 1999 & occupation_status_hrs_number == 0) |
           (year >= 1999 & emp_status %in% c("102 Trainees without special characteristics",
                                             "105 Interns",
                                             "106 Student trainees",
                                             "141 Trainees in maritime shipping"))) %>% 
  mutate(education = forcats::fct_recode(education,
                                `0` = "7",
                                `0` = "8 Completion of education at a specialised upper secondary school/completion of higher education at a specialised college or upper secondary school leaving certificate, A-level equivalent, qualification for university; 13 years of schooling",
                                `0` = "9 Upper secondary school leaving certificate, A-level equivalent, qualification for university; 13 years of schooling"))
 
ind2$education %>% unique()
ind2$education %>% levels()

# Lets define more variables 
ind2 =ind2 %>% 
  mutate(age = year - birthyr) %>% # Age
  # Filter rows based on age criteria
  filter(age >= 20, age <= 60) %>%  # Age between 20 and 60
  mutate(duration = end_date - begin_date + 1) # Duration of the job

#Labels

ind2 = ind2 %>% 
  set_variable_labels(age = "year - birthyr",
                      trainee = "trainee based on occupation status/employer status"
  )

#### Capping the Daily Wage #####

ind2 = ind2 %>%
  mutate(ssmax = NA,
    ssmax = case_when(
      year == 1985 ~ 90,
      year == 1986 ~ 94,
      year == 1987 ~ 95,
      year == 1988 ~ 100,
      year == 1989 ~ 102,
      year == 1990 ~ 105,
      year == 1991 ~ 109,
      year == 1992 ~ 113,
      year == 1993 ~ 121,
      year == 1994 ~ 127,
      year == 1995 ~ 131,
      year == 1996 ~ 134,
      year == 1997 ~ 137,
      year == 1998 ~ 141,
      year == 1999 ~ 142,
      year == 2000 ~ 144,
      year == 2001 ~ 146,
      year == 2002 ~ 147,
      year == 2003 ~ 167,
      year == 2004 ~ 168,
      year == 2005 ~ 170,
      year == 2006 ~ 172,
      year == 2007 ~ 172,
      year == 2008 ~ 173,
      year == 2009 ~ 177,
      year == 2010 ~ 180,
      TRUE ~ ssmax  # Default case to keep original ssmax if year doesn't match
    ),
    censor = 0  # Setting censor to 0 for all rows
  ) %>% 
  mutate(
    censor = ifelse(dailywage >= ssmax, 1, censor),  # Update censor based on condition
    dailywage = ifelse(dailywage >= ssmax, ssmax, dailywage)  # Cap dailywage at ssmax
  )

### CPI on Wage ####

ind2 <- ind2 %>%
  mutate(
    cpi = case_when(
      year == 1985 ~ 80.2,
      year == 1986 ~ 80.1,
      year == 1987 ~ 80.3,
      year == 1988 ~ 81.3,
      year == 1989 ~ 83.6,
      year == 1990 ~ 85.8,
      year == 1991 ~ 89.0,
      year == 1992 ~ 92.5,
      year == 1993 ~ 95.8,
      year == 1994 ~ 98.4,
      year == 1995 ~ 100.0,
      year == 1996 ~ 101.3,
      year == 1997 ~ 103.2,
      year == 1998 ~ 104.1,
      year == 1999 ~ 104.8,
      year == 2000 ~ 106.3,
      year == 2001 ~ 108.4,
      year == 2002 ~ 110.0,
      year == 2003 ~ 111.1,
      year == 2004 ~ 112.9,
      year == 2005 ~ 114.7,
      year == 2006 ~ 116.5,
      year == 2007 ~ 119.1,
      year == 2008 ~ 122.2,
      year == 2009 ~ 122.7
    )
  )  %>%  mutate(
    dailywage = dailywage * 100 / cpi,  # Adjust daily wage based on CPI
    spellearn = as.numeric(duration) * dailywage    # Calculate spell earnings
  )

#Get the days as number of column duration
ind2$spellearn %>% hist()

set.seed(9211093)
ind2 = ind2 %>% 
  mutate(rsample = runif(1)) %>% 
  select(-begin_date, -end_date, -cpi, -ssmax, -emp_status, -occupation_status_hrs, -female)

#### Graphs ####
library(dplyr)
library(ggplot2)


# Calculate summary statistics by 'year'
summary_data <- ind2 %>%
  group_by(year) %>%
  summarise(
    count = n(),
    mean = mean(dailywage, na.rm = TRUE),
    sd = sd(dailywage, na.rm = TRUE),
    min = min(dailywage, na.rm = TRUE),
    max = max(dailywage, na.rm = TRUE)
  )

# Display the summary table
print(summary_data)

# For the title, in R, titles are typically used in plots or reports
# Here's an example of how you might set a title in a ggplot chart
ggplot(summary_data, aes(x = year, y = mean)) +
  geom_line() +
  labs(title = 'FT non-marginal jobs, MEN 1985+, wage>=1, west Germany only') +
  #Lets also add the min and max wage
  geom_point(aes(y = min), color = "red") +
  geom_point(aes(y = max), color = "blue")


