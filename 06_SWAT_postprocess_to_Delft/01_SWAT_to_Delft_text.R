

## Purpose of script:
## Turn csv outputs of SWAT discharge and flow data into the .dis text format 
## required for Delft3D
##
## Author: Greg Slater 
##
## Date Created: 2022-12-01
## ---------------------------


pacman::p_load(tidyverse, lubridate, viridis, RColorBrewer, scales)

source("src/edf_theme.R")
source("src/functions.R")
theme_set(theme_edf())


# Inputs ---------------------------------------------------------------

# This section should be edited to point at SWAT data and set datetime ranges and subbasins

# SWAT discharge output
discharge.df <- read_csv("data/delft3d_inputs_SWAT_total_discharge_20050101_20141231.csv") %>% 
  select(subbasin, datestamp, value = flow_out_cms) %>% 
  mutate(metric = "flow_out_cms")

# SWAT yeild data
yield.df <- read_csv("data/delft3d_inputs_SWAT_local_wyld_20050101_20141231.csv") %>% 
  select(subbasin, datestamp, value = local_water_yield_cms) %>% 
  mutate(metric = "local_water_yield_cms")

swat.df <- bind_rows(discharge.df, yield.df)

# edit these to requirements

date_min <- ymd(20080815)
date_max <- ymd(20080930)
subbasins <- c(215,  225,  236,  239,  252,  242,  231,  240,  270,  285,  286,  253,  210)


# Dis file header text  ---------------------------------------------------------------

# read.table("data/example_discharge/lpt.dis", nrows = 50)

# The .dis file is weird.. It's a number of repeating sections per subbasin, with a 
# section each for discharge and yeild. 
# Each section has its own header describing the data below it.
# This script simply loops through each subbasin in the input SWAT data, edits the 
# dynamic fields in the header text

# header text

header_lines <- c(
  "table-name           'Discharge : ",  # missing " >n'< " cut from the end
  "contents             'regular   '",
  "location             '", # missing " >nnn                 '< " number and spaces for 20 characters total
  "time-function        'non-equidistant'",
  "reference-time       ",  
  "time-unit            'minutes'",
  "interpolation        'linear'",
  "parameter            'time                '                     unit '[min]'",
  "parameter            'flux/discharge rate '                     unit '[m3/s]'",
  "records-in-table     ") # missing " >nn< " cut from the end

# test creating a new header with helper functions
c(hL1Append(1),
  header_lines[2],
  hL3Append(225, ""),
  header_lines[4],
  hL5Append(date_min),
  header_lines[6:9],
  hL10Append(45))


# Filter SWAT data to reqs ------------------------------------------------

# create SWAT discharge table
discharge_write <- filter(swat.df,
                          datestamp >= date_min,
                          datestamp <= date_max,
                          subbasin %in% subbasins)


distinct(discharge_write, subbasin) %>% nrow() == length(subbasins)
distinct(discharge_write, datestamp) %>% nrow() == length(seq(date_min, date_max, "day"))


# Replicate .dis format ----------------------------------------------------

metrics <- c("flow_out_cms", "local_water_yield_cms")
ref_time <- min(swat.df$datestamp)

# output vector and counter
vec_out <- c()
table_counter <- 1


for (m in metrics){
  
  # if (length(vec_out) != 0){break}

  print(m)
  
  # yield char to append to subbasin id is "Y" for yield and missing for flow
  if (m == "flow_out_cms"){
    yield_char = ""
  } else {
    yield_char = "Y"
  }
  
  for (s in subbasins){
    
    # filter extract table to just metric subbasin in loop
    df_subbasin <- filter(swat.df, 
                          subbasin == s,
                          metric == m,
                          datestamp >= date_min,
                          datestamp <= date_max
                          )
    
    print(paste0(m, " subbasin ", s, " is ", nrow(df_subbasin), " records"))
    
    # create edited header with values for subbasin and table num
    edited_header <-c(hL1Append(table_counter),
                      header_lines[2],
                      hL3Append(s, yield_char),
                      header_lines[4],
                      hL5Append(ref_time),
                      header_lines[6:9],
                      hL10Append(nrow(df_subbasin)))
    
    
    # add header to output vector
    vec_out <- append(vec_out, edited_header)
    
    # vector for extracted and formatted df_subbasin data
    vec_sub_text_lines <- c()
    
    # loop through data in df_subbasin and 
    for (r in 1 : nrow(df_subbasin)) {
      
      vec_sub_text_lines <- append(vec_sub_text_lines, 
                                   dfToText(df_subbasin, r))
      
    }
    
    #     append formatted df_subbasin data to vec_out
    vec_out <- append(vec_out, vec_sub_text_lines)
    
    table_counter <- table_counter + 1
  }
}




fileConn<-file("output/test_lpt_1.2_discharge_yield.dis")
writeLines(vec_out, fileConn)
close(fileConn)