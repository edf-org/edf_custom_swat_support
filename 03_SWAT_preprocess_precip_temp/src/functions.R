
library(tidyverse)


add_date <- function(file) {
  
  # read in text file, ignoring date header and adding precip as column name
  df <- read_csv(paste0("data/Deliverables/", file), col_names = "precip", skip = 1, col_types = cols())
  
  # create date column with a sequence of dates from 19800101 to the end of the table length
  df$date <- seq(ymd(19800101), ymd(19800101) + days(nrow(df) -1), "days")
  
  df
}


add_date_sub <- function(file, cols) {
  
  # read in text file, ignoring date header and adding precip as column name
  df <- read_csv(paste0("data/Deliverables/", file), col_names = cols, skip = 1, col_types = cols())
  
  # create date column with a sequence of dates from 19800101 to the end of the table length
  df$date <- seq(ymd(19800101), ymd(19800101) + days(nrow(df) -1), "days")
  
  # create sub column based on sub value in filename
  df$sub <- as.numeric(strsplit(file, split = "_")[[1]][2])
  
  df
}
