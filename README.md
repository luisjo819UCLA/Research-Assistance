# SAS to R Code Translation: Data Transformation and Tobit Model Analysis

## Project Overview

This repository contains an R script designed to translate a comprehensive SAS code to R, with a focus on data transformation, manipulation, and Tobit model analysis for survival data. The project loads, cleans, and processes multiple datasets to prepare them for statistical modeling, with specific transformations tailored to align with SAS-specific operations.

## Objectives

1. **Data Import and Cleaning**: Load `.dta` files, clean and format the data.
2. **Data Merging**: Merge individual and firm-level data based on common identifiers.
3. **Data Filtering**: Apply filters to standardize the dataset and remove outliers.
4. **Variable Transformation**: Create new variables to support statistical analysis and Tobit modeling.
5. **Tobit Model Application**: Implement a Tobit model to analyze censored data.

## Project Structure

The project primarily uses **R** and leverages libraries such as `data.table`, `dplyr`, `tidyverse`, `lubridate`, and `AER` (for the Tobit model). It includes the following main steps:

### 1. Data Import and Initial Inspection
- **Files in `SIEED_7518_v1_test` folder** are loaded and stored in lists, allowing for exploration of variable labels and formats.
- Labels are set to English for consistency.

### 2. Data Merging and Cleaning
- **Individual Data** (`ind`) and **Business Basis Data** (`basis`) are merged on identifiers like year and business number.
- Variables are renamed for clarity, and new columns are created for state and occupation codes.

### 3. Data Filtering and Transformation
- Filtering criteria are applied to restrict data based on gender, state, employment status, and occupation type.
- The daily wage is adjusted based on historical CPI data, and trainees are identified based on employment status.

### 4. Defining New Variables
- **Age and job duration** are computed, with additional transformations to create federal and occupation status codes.

### 5. Capping the Daily Wage
- **Daily wage is capped** at maximum threshold values by year, with additional censoring information added to the dataset.

### 6. Data Grouping and Summarization
- **Firm-level** and **year-level data** are summarized to support Tobit modeling, with descriptive statistics calculated.

### 7. Tobit Model Implementation
- A Tobit model is applied to the censored dataset for specific time periods and subgroups, using variables like age, schooling, and firm characteristics.
- **Coefficients are stored** in a results dataframe, `WORK_tobit`.

### 8. Data Modification for GLM Analysis
- Predictions from GLM models are stored as new variables, and **residuals** are calculated for further analysis.

## Key Libraries

- **Data Management**: `dplyr`, `data.table`, `tidyverse`, `lubridate`
- **Statistical Modeling**: `AER` for Tobit regression, `ggplot2` for visualization
- **Data Input**: `haven`, `readstata13`

## Files in Repository

- `first.R`: The primary script containing the translated code from SAS to R.
- `.dta` files: Data files are expected to be located in a folder named `SIEED_7518_v1_test` for the code to function correctly.

## Installation and Usage

1. **Clone the repository**:
    ```bash
    git clone https://github.com/your-username/your-repository.git
    cd your-repository
    ```

2. **Install Required Libraries**:
    ```R
    install.packages(c("data.table", "dplyr", "tidyverse", "lubridate", "haven", "AER", "readstata13"))
    ```

3. **Run the Script**:
    Open `first.R` in your R environment and run the code step-by-step or execute the entire script to replicate the analysis.

## Results and Visualization

The final output includes processed data frames (`WORK_py`, `WORK_pyx`, `WORK_fy`, etc.) containing variables like capped daily wages, experience terms, and other derived features. Graphical visualizations and summary tables are generated to inspect data distribution and trends over time.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

--- 

