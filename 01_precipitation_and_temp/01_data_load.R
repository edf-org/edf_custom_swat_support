
pacman::p_load(tidyverse, lubridate, RColorBrewer, scales, sf)

source("src/edf_theme.R")
source("src/functions.R")
theme_set(theme_edf())


# Load data ---------------------------------------------------------------


pattern <- "PCP.txt"

# list of all precipitation filenames
files_short <- list.files(path="data/Deliverables/", pattern=pattern)

# for each file, read in and add date to dataframe, then write to csv in output folder
for (f in files_short[1:1]) {
  
  df <- add_date_sub(f, cols="precip")
  
  write_csv(df, paste0("output/precip/", f))
}




pattern <- "TMP.txt"

# list of all filenames
files_short <- list.files(path="data/Deliverables/", pattern=pattern)

# for each file, read in and add date to dataframe, then write to csv in output folder
for (f in files_short[1:1]) {
  
  df <- add_date_sub(f, cols=c("max", "min"))
  
  write_csv(df, paste0("output/temp_dated/", f))
}

