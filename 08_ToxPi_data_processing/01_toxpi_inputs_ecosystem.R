
## Purpose of script: 
## Read in the ecosystem raster datasets, warp them to the raster_template,
## and save new rasters and csvs
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

# directory with Ecosystem data
dir_in <- "C:/Users/gslater/OneDrive - Environmental Defense Fund - edf.org/GCA Work/edf_custom_swat_support/08_ToxPi_data_processing/data/ToxPi_inputs/Costing_nature/"

# directory for ouputs
dir_out <- "output/ToxPi_inputs_processed/Ecosystem/"


# read in rasters to list and warp
f_names <- list.files(path=dir_in, pattern='.tif', full.names = TRUE) 

eco_warped <- lapply(f_names, function(x){
  read_stars(x) %>%
    st_warp(rt, method = 'near', use_gdal = TRUE)
})


# write out warped rasters
for (i in 1:length(eco_warped)){
  # take end of filename from path and write
  path_arr <- strsplit(f_names[[i]], "/")[[1]]
  fname <- path_arr[[length(path_arr)]]
  
  write_stars(eco_warped[[i]], paste0(dir_out, "processed_", fname))
}

# write out to csv
for (i in 1:length(eco_warped)){
  # take end of filename from path
  path_arr <- strsplit(f_names[[i]], "/")[[1]]
  fname <- path_arr[[length(path_arr)]] %>% 
    str_replace(".tif", ".csv")
  
  # convert warped raster to df and write out
  eco_warped[[i]] %>% 
    raster_to_df() %>% 
    drop_na() %>%
    write_csv(paste0(dir_out, "processed_", fname))
}


