## Purpose of script: 
## Transform the shapefile SWAT outputs into raster and save as csv
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

# SWAT data
bfull <- st_read("data/ToxPi_inputs/SWAT/SWAT_bankfull_duration_floodplain_clip/SWAT_bankfull_duration_floodplain_clip.shp") %>%
  rename(event_duration_days = bquxjob_5f,
         max_event_duration_days = bquxjob__1)


# PROCESSING --------------------------------------------------------------

# process to raster for: event_duration_days
bfull_days.rt <- sf_to_raster(bfull, "event_duration_days", rt)
bfull_days.df <- raster_to_df(bfull_days.rt)

# process to raster for: max_event_duration_days
bfull_days_max.rt <- sf_to_raster(bfull, "max_event_duration_days", rt)
bfull_max.df <- raster_to_df(bfull_days_max.rt)

# output both rasters
write_stars(bfull_days.rt, "output/ToxPi_inputs_processed/SWAT/bankfull_event_duration_days.tif")
write_stars(bfull_days_max.rt, "output/ToxPi_inputs_processed/SWAT/bankfull_event_duration_days_max.tif")

nrow(bfull_days.df) == nrow(bfull_max.df)

# create df with both vars and write
df_comb <- data.frame(cell_id = bfull_days.df$cell_id,
                      event_duration_days = bfull_days.df$value,
                      max_event_duration_days = bfull_max.df$value)

write_csv(df_comb %>% drop_na(), "output/ToxPi_inputs_processed/SWAT/bankfull_event_duration.csv")
