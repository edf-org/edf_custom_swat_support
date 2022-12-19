## Purpose of script: 
## Transform csv outputs from ToxPi into rasters for mapping
## 
## Author: Greg Slater 
##
## Date Created: 2022-10-26


## load up packages

pacman::p_load(tidyverse, lubridate, stars, janitor)

source("src/edf_theme.r")
source("src/functions.r")

# DATA IN -----------------------------------------------------------------

# Instructions: update the fpath below to a ToxPi csv output and the folder
# to the output folder you want, and the processing steps will save all 
# variables from the csv (apart from cell_id) as separate raster files
# note - make sure the ToxPi csv has a field called cell_id (rename from grid_id) if necessary..

toxpi_fpath <- "data/ToxPi_outputs/2022_10_14/NAS_toxpi_scale-allinone-10-14-22.csv"
# toxpi_fpath <- "data/ToxPi_outputs/2022_08_08/NAS_toxpi_facility-allinone-08-08-2022.csv"

output_folder <- "output/ToxPi_outputs_processed/"

# raster template
rt <- read_stars("data/raster_template/raster_template.tif")


# PROCESSING --------------------------------------------------------------

# read in file and make clean names
tp <- read_csv(toxpi_fpath) %>% 
  janitor::clean_names()

# remove cell_id to get list of just ToxPi variable names
tp_var_names <- names(tp)[names(tp) != "cell_id"]

# run through vars, convert csv data to raster, and save
for (var in tp_var_names){

  # print(paste0(output_folder, v, ".tif"))  
  tp %>%
    csv_to_raster("cell_id", var, rt) %>%
    write_stars(paste0(output_folder, var, ".tif"))
}



# Decile 10 cells only ----------------------------------------------------

# export subset for dashboard
deciles_10_rt <- tp %>% 
  mutate(decile = ntile(tox_pi_score, 10)) %>%
  filter(decile == 10) %>%
  csv_to_raster("cell_id", "decile", rt)

write_stars(deciles_10_rt, paste0(output_folder, "tox_pi_score_dec10_only.tif"))
