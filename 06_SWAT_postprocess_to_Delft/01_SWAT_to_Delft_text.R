

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

# SWAT discharge output - interior conditions
discharge.df <- read_csv("data/delft3d_inputs_SWAT_total_discharge_20050101_20201231.csv") %>% 
  select(subbasin, datestamp, value = flow_out_cms) %>% 
  mutate(metric = "flow_out_cms")

# SWAT yield data - boundary conditions
yield.df <- read_csv("data/delft3d_inputs_SWAT_local_wyld_20050101_20201231.csv") %>% 
  select(subbasin, datestamp, value = local_water_yield_cms) %>% 
  mutate(metric = "local_water_yield_cms")

# combine SWAT inputs into single narrow table
swat.df <- bind_rows(discharge.df, yield.df)


# EDIT THESE FIELDS TO MATCH REQUIREMENTS!!

date_min <- ymd(20170101)
date_max <- ymd(20171231)
subbasins <- c(210, 211, 215, 225, 231, 236, 239, 240, 242, 252, 253, 270, 281, 282, 285, 286)


# USE THIS TO DEFINE A MANUAL ORDER FOR THE SUBBASINS IF THIS IS REQUIRED
# keep this field in, if order doesn't matter just keep the same as subbasins above
subbasin_order <- subbasins

# define name for output .dis file - this will be saved in /output (note - no need for .dis here)
output_fname <- "laporte_2017"

# Dis file header text  ---------------------------------------------------------------

# read.table("data/example_discharge/lpt.dis", nrows = 50)

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

# create a table of just the SWAT data to transform into .dis format
discharge_write <- filter(swat.df,
                          datestamp >= date_min,
                          datestamp <= date_max,
                          subbasin %in% subbasins)
  

# check n subbasins and n days in the data to transform matches the requirements
distinct(discharge_write, subbasin) %>% nrow() == length(subbasins)
distinct(discharge_write, datestamp) %>% nrow() == length(seq(date_min, date_max, "day"))


# Replicate .dis format ----------------------------------------------------

# the two metrics to be output
metrics <- c("flow_out_cms", "local_water_yield_cms")
# reference time (for the header) is the minimum date in the input data
# this is used to calculate the time field for the .dis file which is minutes from reference time
ref_time <- min(discharge_write$datestamp)

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
    subbasin_order = subbasins
  }
  
  if(length(subbasins) != length(subbasin_order)){
    print("WARNING - the number of subbasins required doesn't the number in the order list. Correct and re-run")
    break
  }
  
  for (s in subbasin_order){
    
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
    
    # append formatted df_subbasin data to vec_out
    vec_out <- append(vec_out, vec_sub_text_lines)
    
    table_counter <- table_counter + 1
  }
}



fileConn<-file(paste0("output/", output_fname, ".dis"))
writeLines(vec_out, fileConn)
close(fileConn)