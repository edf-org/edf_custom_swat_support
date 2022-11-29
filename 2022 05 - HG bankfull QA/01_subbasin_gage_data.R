
## Purpose of script: 
## Spatial join between USGS gage locations and study area subbasin
## to create lookup between them
## 
## Author: Greg Slater 
##
## Date Created: 2022-11-07
## ---------------------------

## load up packages
pacman::p_load(tidyverse, lubridate, paletteer, scales, sf)

source("src/edf_theme.R")
source("src/functions.R")
theme_set(theme_edf())

# DATA IN -----------------------------------------------------------------

# read in gages txt file
gages <- read_delim("data/USGS/usgs_gages_120302_1204.txt", ",") %>%
  mutate(site_no = paste0("0", as.character(site_no)))

# turn into sf
gages_sf <- st_as_sf(gages, coords = c('dec_long_va', 'dec_lat_va'), crs=4269) %>%
  st_transform(6587) %>%
  select(site_no, station_nm)

# gages_sf %>% st_write("output/spatial/gages/USGS_study_area_gages.shp")

# read in subbasin sf
subs_sf <- st_read("data/spatial/subbasin/subs1_fixed.shp") %>%
  select(subbasin = Subbasin)



# check subs and gages data intersects
ggplot() +
  geom_sf(data = subs_sf, fill = NA, col = "grey60") +
  geom_sf(data = gages_sf, size = 1, col = "cyan4") +
  coord_sf(datum = NA) +
  theme_minimal()



# SPATIAL JOINS --------------------------------------------------------------------
# we want to intersect the gages with the subbasins so we can compare SWAT with USGS


sub_gage_sf <- subs_sf %>% 
  st_intersection(gages_sf) %>%
  arrange(subbasin) %>%
  mutate(usgs_site_no = paste0("0", as.character(site_no)))

# save lookup table between gages (site_id) and subbasins (subbasin)
sub_gage_df <- sub_gage_sf %>% st_set_geometry(NULL)

# sub_gage_df %>% write_csv("output/subbasin_gage_lookup.csv")
