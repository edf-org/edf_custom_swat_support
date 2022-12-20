
## Purpose of script: 
## Combine the Delft3D rasters which all contain non-overlapping
## subsets of data within the same area, and combine them into single csv and raster files
## 
## Author: Greg Slater 
##
## Date Created: 2022-10-26


## load up packages

pacman::p_load(tidyverse, lubridate, stars, sf)

source("src/edf_theme.r")
source("src/functions.r")

# DATA IN -----------------------------------------------------------------

# raster template
rt <- read_stars("data/raster_template/raster_template.tif")


# PROCESSING --------------------------------------------------------------

# Directory with Delft data (masked)
dir_in <- "C:/Users/gslater/OneDrive - Environmental Defense Fund - edf.org/GCA Work/edf_custom_swat_support/08_ToxPi_data_processing/data/ToxPi_inputs/Delft3D"

# list of masked files
f_names <- list.files(path=dir_in, pattern='_mask.tif', full.names = TRUE) 


# read in, warp, convert to df, remove -999s and drop NAs
# then bind into one table

delft_comb <- lapply(f_names, function(x){
  read_stars(x) %>%
    st_warp(rt, method = 'near', use_gdal = TRUE) %>%
    raster_to_df() %>%
    filter(value != -999) %>%
    drop_na()
}) %>%
  bind_rows()

# write combined table to csv
delft_comb %>%
  write_csv("output/ToxPi_inputs_processed/Delft3D/depth_all_clipped_2022_10_24.csv")


# convert back to raster then write out to TIF
delft_comb %>%
  csv_to_raster("cell_id", "value", rt) %>% 
  write_stars("output/ToxPi_inputs_processed/Delft3D/depth_all_raster_template_clipped.tif")
