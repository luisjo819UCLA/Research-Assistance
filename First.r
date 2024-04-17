# Assuming the necessary libraries are installed
library(data.table)#For survival analysis, might need adaptations for Tobit models
library(dplyr) # For data manipulation
library(tidyverse) # For data manipulation
library(lubridate)  # For easy date handling
library(haven) # For reading Stata files
library(labelled)
#This only works with the Working Directory at the folder where this file is contained

#Lets see all the dta files that are in the folder SIEED_7518_v1_test
dta_files = list.files("SIEED_7518_v1_test", pattern = ".dta")

#Lets read the dta files and store them in a list
dta_list = lapply(dta_files, function(x) read_dta(paste0("SIEED_7518_v1_test/", x)))

#We see the labels of the data
dta_list[[1]] %>% 
  look_for()
#We read the V1 (individuals) data
library(readstata13)
dta_label2 = lapply(dta_files, function(x) read.dta13(paste0("SIEED_7518_v1_test/", x)))

dta_label2[[2]] %>% 
  class()
#Change the label to english
dta_label2 = lapply(dta_label2, function(x) x %>% set.lang("en"))
#Lets see the head of the dta_list

#On dta_files there are data with year on the name, and other without it. Lets filter the ones with year on the name
dta_files_2 = dta_files[str_detect(dta_files, "^(SIEED_7518_v1_bhp_20|SIEED_7518_v1_bhp_19)")]

dta_files_3 = dta_files[!dta_files %in% dta_files_2]

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


### Read dta ####

library(readstata13)
#Individual data
ind = read.dta13("SIEED_7518_v1_test/SIEED_7518_v1.dta") %>% 
  set.lang("en") #We set the labels to english
ind %>% attributes() %>% names()
ind_label = ind %>%
  attr("var.labels") #we get the labels of the data
for (i in 1:length(ind_label)){
  ind = ind %>% set_variable_labels(!!names(ind)[i] := ind_label[[i]]) #We set the labels to the data
}
#Business. Basis
basis = read.dta13("SIEED_7518_v1_test/SIEED_7518_v1_bhp_basis_v1.dta") %>% 
  set.lang("en") #We set the labels to english

bas_label = basis %>%
  attr("var.labels") #we get the labels of the data
for (i in 1:length(bas_label)){
  basis = basis %>% set_variable_labels(!!names(basis)[i] := bas_label[[i]]) #we set the labels to the data
}

#Lets merge ind and basis. We merge by jahr, which is the year of the data, and by betnr, which is the business number
ind_basis = ind %>%
  mutate(jahr = year(begepi)) %>% #We extract the year from the date
  left_join(basis, by = c("jahr", "betnr")) #We merge by year and business number


#### Rename ####
ind2 = ind_basis %>% rename(
  id = persnr,
  firmid = betnr,
  birthyr = gebjahr,
  education = ausbildung_imp,
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
## Data Modification ####
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
#### Imposing restrictions####
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
                         210), # drop marginal jobs for comparability over time
           occupation_status_hrs_number >= 0 & occupation_status_hrs_number <= 4) #Between vocational training, unskilled worker, skilled worker, blue/white collar and full-time employment (drop part time jobs)
         
ind2$education %>% unique()
#continue the restrictions
ind2 = ind2 %>% 
  mutate(trainee = (year < 1999 & occupation_status_hrs_number == 0) |
           (year >= 1999 & emp_status %in% c("102 Trainees without special characteristics", #define trainees
                                             "105 Interns",
                                             "106 Student trainees",
                                             "141 Trainees in maritime shipping"))) %>%  #Lets change the value of the factor "education" to 0 if is na
  mutate(education = if_else(is.na(education), as.factor(0), as.factor(education)))  #Redefine education


#### Lets define new variables  ####
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

#### CPI on Wage ####

ind2 <- ind2 %>%
  mutate(
    cpi = case_when( #Also here
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
    ) #Find new CPI
  )  %>%  mutate(
    dailywage = dailywage * 100 / cpi,  # Adjust daily wage based on CPI
    spellearn = as.numeric(duration) * dailywage    # Calculate spell earnings
  )

#Get the days as number of column duration
ind2$spellearn %>% hist()

set.seed(9211093)
ind2 = ind2 %>% 
  mutate(rsample = runif(nrow(ind2))) %>% 
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

# Filter the data
#Lets extract the 3 numbers of the SIC code
ind2 = ind2 %>%
  mutate(sic_code_1_n = str_extract(sic_code1, "\\d+") %>% as.numeric(), #Extract the number of the federal state
         sic_code_1_l = str_extract(sic_code1, "\\D+")) #Extract the name of the federal state
  
ind3 = ind2 %>%
filter(rsample > 0.95, year >= 1985, year <= 1991)

# Check distributions of 'occupation' and 'w73_3' by 'year'
# For 'occupation' lets plot with tittle
ind3$occupation %>% table() %>% barplot(main = "Occupation Distribution of 5%")
beruf_table <- table(ind3$occupation)

# For 'w73' by 'year'
w73_year_freq <-  ind3 %>%
  count(sic_code1, year)
print(w73_year_freq)
ggplot(w73_year_freq, aes(x = year, y = n, fill = sic_code1)) +
  geom_col() +
  labs(title = '5 percent sample, 1985-91 only',
       x = 'Year',
       y = 'Frequency',
       fill = 'SIC Code (w73)') +
  theme_minimal() + #Lets errase the legend using theme
  theme(legend.position = "none")

filtered_data_2 <- ind2 %>%
  filter(rsample > 0.95, year >= 1992 & year <= 1998)

# Compute frequency table for 'w73' by 'year'
# You can adjust this to also include 'beruf' if needed
w73_year_freq <- filtered_data_2 %>%
  count(sic_code1, year)

# Plotting the frequency distribution of 'w73' by 'year'
ggplot(w73_year_freq, aes(x = year, y = n, fill = sic_code1)) +
  geom_col() +
  labs(title = '5 percent sample, 1992-98 only',
       x = 'Year',
       y = 'Frequency',
       fill = 'SIC Code (w73)') +
  theme_minimal() + #Lets errase the legend using theme
  theme(legend.position = "none")

filtered_data_3 <- ind2 %>%
  filter(rsample > 0.95, year >= 1997 & year <= 2003)

# Compute frequency table for 'beruf', 'w73' by 'year', and 'w93' by 'year'
# Here we focus on 'w73' and 'w93' by 'year' as an example
w73_year_freq <- filtered_data_3 %>%
  count(sic_code1, year)

w93_year_freq <- filtered_data_3 %>%
  count(sic_code2, year)

# Plotting the frequency distribution of 'w73' by 'year'
ggplot(w73_year_freq, aes(x = year, y = n, fill = sic_code1)) +
  geom_col() +
  labs(title = '5 percent sample, 1997-2003 only',
       x = 'Year',
       y = 'Frequency',
       fill = 'SIC Code (w73)') +
  theme_minimal() + #Lets errase the legend using theme
  theme(legend.position = "none")

# Plotting the frequency distribution of 'w93' by 'year'
ggplot(w93_year_freq, aes(x = year, y = n, fill = sic_code2)) +
  geom_col() +
  labs(title = '5 percent sample, 1997-2003 only',
       x = 'Year',
       y = 'Frequency',
       fill = 'SIC Code (w93)') +
  theme_minimal() + #Lets errase the legend using theme
  theme(legend.position = "none")
#There are some missings to see later.
#W73: This variable indicates the economic activity as a 3-digit code in accordance with 
#the WS73 classification and is available from 1975 up to and including 2002.

#W93: This variable indicates the economic activity as a 3-digit code in accordance with
#the WZ93 classification and is available from 1999 up to and including 2003.

library(dplyr)
library(ggplot2)

# Filter the data
filtered_data_4 <- ind2 %>%
  filter(rsample > 0.95, year >= 2003 & year <= 2009)

# Compute frequency tables for 'beruf', 'w73' by 'year', 'w93' by 'year', and 'w03' by 'year'
beruf_freq <- filtered_data_4 %>% count(occupation)
w73_year_freq <- filtered_data_4 %>% count(sic_code1, year)
w93_year_freq <- filtered_data_4 %>% count(sic_code2, year)
w03_year_freq <- filtered_data_4 %>% count(sic_code3, year)

#There is not data for 273 after 2003
# Similarly, create plots for 'w93' by 'year' and 'w03' by 'year'
# Example for 'w93'
ggplot(w93_year_freq, aes(x = year, y = n, fill = sic_code2)) +
  geom_col() +
  labs(title = '5 percent sample, 2003-2009 only, w93 by year',
       x = 'Year',
       y = 'Frequency',
       fill = 'SIC Code (w93)') +
  theme_minimal() + #Lets errase the legend using theme
  theme(legend.position = "none")

# Example for 'w03'
ggplot(w03_year_freq, aes(x = year, y = n, fill = sic_code3)) +
  geom_col() +
  labs(title = '5 percent sample, 2003-2009 only, w03 by year',
       x = 'Year',
       y = 'Frequency',
       fill = 'SIC Code (w03)') +
  theme_minimal() + #Lets errase the legend using theme
  theme(legend.position = "none")

### Collapse to person-firm-year ####

library(dplyr)

# Assuming 'data' is your R data frame equivalent to WORK.one in SAS
get_mode <- function(x) { # Define a function to get the mode of a vector (for factors)
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))] # Return the most frequent value
}

pfy <- ind2 %>%
  group_by(id, firmid, year) %>% # Group by 'id', 'firmid', and 'year'
  summarise(
    totduration = sum(duration %>% as.numeric(), na.rm = TRUE),
    totearn = sum(spellearn, na.rm = TRUE),
    dailywage = totearn / totduration,
    logwage = log(dailywage),
    trainee = max(trainee, na.rm = TRUE),
    age = max(age, na.rm = TRUE),
    birthyr = max(birthyr, na.rm = TRUE),
    occupation = get_mode(occupation), #Is max in code, but its the occupation code, so used the mode
    w73 = get_mode(sic_code1),
    w93 = get_mode(sic_code2),
    w03 = get_mode(sic_code3),
    federal_state = get_mode(federal_state),
    education = (education %>% unique() %>% as.numeric() %>% max()),
    schule = (schule %>% unique() %>% as.numeric() %>% max()),
    censor = if (all(is.na(censor))) NA else max(censor, na.rm = TRUE)
  ) %>% 
  mutate(logwage = ifelse(is.infinite(logwage), NA, logwage)) 

names(pfy)
library(dplyr)

# Calculate and display summary statistics for all numeric columns, grouped by 'year'
pfy_stats <- pfy %>% ungroup() %>%
  select(-id, -firmid) %>%
  group_by(year) %>%
  summarise(across(where(is.numeric), 
                   list(n = ~ n(),
                        mean = ~ mean(., na.rm = TRUE),
                        sd = ~ sd(., na.rm = TRUE),
                        min = ~ min(., na.rm = TRUE),
                        max = ~ max(., na.rm = TRUE)),
                   .names = "{.col}_{.fn}"))  # to differentiate the statistics

# View the summarized data
glimpse(pfy_stats)
####Selecting the higest earning pfy as py ####

pfy_tot = pfy %>% 
  ungroup() %>%
  arrange(id, year, desc(totearn)) %>%
  group_by(id, year) %>%
  slice(1) %>%
  ungroup()

#Lets plot the totearn, where x would be the year and y the totearn, and id would be the group
ggplot(pfy_tot, aes(x = year, y = totearn)) +
  geom_line(aes(color = as.factor(id)),alpha=0.2) +
  labs(title = 'Total earnings by year',
       x = 'Year',
       y = 'Total Earnings') +
  theme_minimal() + #Lets errase the legend using theme
  theme(legend.position = "none") +
  geom_smooth(se = FALSE)
 
### Restriction on Real Wage####
ind2 %>% 
  select(education) %>% 
  mutate(otro = as.numeric(education)) %>% 
  unique() %>% View()
library(dplyr)
#For this i got to rework education. 
#Will use 0 for the qualifications of dropout, aprentice, university and missed

# education == ".z no entry" ~ 10.5, # NA_real_ is used to represent missing numeric values
# education == "1 Secondary / intermediate school leaving certificate without completed vocational training" ~ 10.5,
# education == "2 Secondary / intermediate school leaving certificate with completed vocational training" ~ 11,
# education == "3 Upper secondary school leaving certificate (General or subject-specific) without completed vocational training" ~ 13,
# schule == "8 Completion of education at a specialised upper secondary school/completion of higher education at a specialised college or upper secondary school leaving certificate, A-level equivalent, qualification for university; 13 years of schooling" ~ 13,
# schule == "9 Upper secondary school leaving certificate, A-level equivalent, qualification for university; 13 years of schooling " ~ 13,
# education == "4 Upper secondary school leaving certificate (General or subject-specific) with completed vocational training" ~ 15,
# education == "5 Completion of a university of applied sciences" ~ 18,
# education == "6 College / university degree" ~ 18,

WORK_py = pfy_tot %>%
  mutate(
    schooling = case_when(
      is.na(education) ~ 10.5,
      is.na(schule) ~ 10.5,
      education == 1 ~ 10.5, # NA_real_ is used to represent missing numeric values
      education == 2 ~ 10.5,
      education == 3 ~ 11,
      education == 4 ~ 13,
      schule == 8 ~ 13,
      schule == 9 ~ 13,
      education == 5 ~ 15,
      education == 6 ~ 18,
      education == 7 ~ 18,
    )
  ) %>% 
  mutate(
    edgroup = case_when(
      schooling == 10.5 ~ 0,
      schooling == 11 ~ 1,
      schooling == 13 ~ 2,
      schooling == 15 ~ 3,
      schooling == 18 ~ 4,
    )
  )  %>% 
  mutate(agegroup = case_when(
    age >= 20 & age <= 29 ~ 2,
    age >= 30 & age <= 39 ~ 3,
    age >= 40 & age <= 49 ~ 4,
    age >= 50 ~ 5
  ),
  exp = case_when(
    TRUE ~ age - 25,
    edgroup %in% c(0, 1, 2) ~ age - 18,
    edgroup == 3 ~ age - 22
  )) %>% 
  mutate(dropout = as.integer(edgroup == 1),
         apprentice = as.integer(edgroup == 2),
         somecoll = as.integer(edgroup == 3),
         university = as.integer(edgroup == 4),
         missed = as.integer(edgroup == 0)) %>%
  select(-education)
#Change labels
WORK_py = WORK_py  %>% set_variable_labels(
  totearn = 'tot earns in p-f-year',
  totduration = 'total days worked in p-f-year',
  trainee = 'spell as trainee in p-f-year',
  dailywage = 'avg daily wage, p-f cell',
  logwage = 'log daily wage, dropped if under 10 e/day'
)


#### Data by firm and year for TOBIT ####
library(dplyr)

WORK_fy <- WORK_py %>%
  group_by(firmid, year) %>% #group by firm and year
  summarise(
    emp = sum(!is.na(logwage)),  # Count number of employes by firm and year
    fmeanlogwage = mean(logwage, na.rm = TRUE), #average
    fmeancensor = mean(censor, na.rm = TRUE),
    fmeanschooling = mean(schooling, na.rm = TRUE),
    fmeanuniversity = mean(university, na.rm = TRUE),
    fmeansomecoll = mean(somecoll, na.rm = TRUE),
    fmeanapprentice = mean(apprentice, na.rm = TRUE),
    fmeanexp = mean(exp, na.rm = TRUE),
    fmeanexpsq = mean(exp * exp / 100, na.rm = TRUE)
  ) %>%
  ungroup()  # Remove the grouping structure

# View the resulting data frame
print(WORK_fy)

library(dplyr)

#### Now we group by id ####
WORK_pall <- WORK_py %>%
  group_by(id) %>%
  summarise(
    pfirstyear = min(year),
    plastyear = max(year),
    pnyears = n(),
    pn8589 = sum(year >= 1985 & year <= 1989),
    pn9094 = sum(year >= 1990 & year <= 1994),
    pn9599 = sum(year >= 1995 & year <= 1999),
    pn0004 = sum(year >= 2000 & year <= 2004),
    pn0509 = sum(year >= 2005 & year <= 2009),
    pmeanlogwage = mean(logwage, na.rm = TRUE),
    pmeancensor = mean(censor, na.rm = TRUE)
  ) %>%
  ungroup()  # Ensure the resulting data frame is not grouped

# View the resulting data frame
print(WORK_pall)
### Work with unified data for TOBIT ####
WORK_pyx <- WORK_py %>%
  left_join(WORK_fy, by = c("firmid", "year")) %>%
  left_join(WORK_pall, by = "id")

# View the structure of the new data frame
WORK_pyx %>% 
  glimpse()

library(dplyr)

WORK_pyx <- WORK_pyx %>%
  mutate(
    # Create new variables
    onewkr = as.integer(emp == 1), #One employer firm
    atbigfirm = as.integer(emp > 10),
    oneyear = as.integer(pnyears == 1), #One year worker
    
    # Conditional calculations for firm-level stats (one worker firm)
    ofmeancensor = ifelse(onewkr == 0, (fmeancensor - censor / emp) * emp / (emp - 1), 0.1),
    ofmeanwage = ifelse(onewkr == 0, (fmeanlogwage - logwage / emp) * emp / (emp - 1), 4.8),
    
    # Conditional calculations for person-level stats (just one year period)
    opmeancensor = ifelse(oneyear == 0, (pmeancensor - censor / pnyears) * pnyears / (pnyears - 1), 0.1),
    opmeanwage = ifelse(oneyear == 0, (pmeanlogwage - logwage / pnyears) * pnyears / (pnyears - 1), 4.8),
    
    # Additional calculations
    empsq = emp * emp / 100
  )

# Create a 3% sample for tobits using base R's runif for random number generation
set.seed(921) # Ensure reproducibility
WORK_pyx <- WORK_pyx %>%
  mutate(
    random_value = runif(n(), min = 0, max = 1),  # Generate and store random numbers
    insub = as.integer(random_value >= 0.47 & random_value < 0.5)  # Use the stored random numbers for the condition
  ) %>% 
  select(-random_value)  # Remove the random number column
# Check results
print(head(WORK_pyx))

#### Final data #####
library(dplyr)

# Assuming WORK_pyx is already loaded into an R data frame named WORK_pyx
WORK_sub <- WORK_pyx %>%
  #filter(insub == 1) %>%
  select(logwage, censor, age, atbigfirm, ofmeancensor, ofmeanwage, emp, empsq, onewkr,
         fmeanuniversity, fmeanschooling, opmeancensor, opmeanwage, oneyear, year, edgroup, agegroup)

# View the structure of the new data frame
WORK_sub %>% names()

### TOBIT #### 
library(dplyr)

# Create an initial empty data frame as dummy to start the loop

WORK_tobit <- data.frame(
  year = integer(1),
  edgroup = integer(1),
  agegroup = integer(1)
)
WORK_tobit[1,] <- c(0, 0, 0)

library(AER)
library(dplyr)

# Loop through the specified years, education groups, and age groups
for (yr in 1985:2009) {
  for (eg in 0:4) {
    for (ag in 2:5) {
      # Filter data for the current subgroup
      subset_data <- WORK_sub %>% 
        ungroup() %>% 
        filter(year == yr, edgroup == eg, agegroup == ag)
      
      censoring_point = mean(subset_data$logwage[subset_data$censor == 1], na.rm=TRUE)
      if(is.na(censoring_point)) {
        next
      }
        # Fit the Tobit model
        tobit_model <- tobit(logwage ~ age + atbigfirm + ofmeancensor + ofmeanwage + emp + empsq + onewkr +
                               fmeanuniversity + fmeanschooling + opmeancensor + opmeanwage + oneyear,
                             right = censoring_point,  # Adjust as per censoring info
                             y = -Inf,
                             data = subset_data)
        
        # Save or output model summary; adapt this part as needed for your output requirements
        print(summary(tobit_model))
      }
    }
  }
}

