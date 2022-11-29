
## Purpose of script: 
## To match facility locations to land parcels in the study area and classify
## the quality of the matching. Output is a facility > parcel lookup table.
## 
## Author: Greg Slater 
##
## Date Created: 2022-11-22
## ---------------------------

## load up packages

pacman::p_load(tidyverse, lubridate, RColorBrewer, scales, sf, stars)

source("src/edf_theme.R")
source("src/functions.R")
theme_set(theme_edf())


# DATA IN ---------------------------------------------------------------

# all facilities data
fac_all.df <- read_csv("output/facilities/facilities_all_coded_2022-11-23.csv", guess_max = 2000) %>% 
  rename(registry_id = REGISTRY_ID)


fac_all.sf <- fac_all.df %>% 
  filter(!is.na(lat_merge)) %>% 
  st_as_sf(coords = c('lon_merge', 'lat_merge'), crs=4269) %>% 
  select(registry_id, latlon_merge_src)

# parcels data - limited (in QGIS) to just those within 100m of facilities, or with industrial land use
parc.sf <- st_read("data/parcels/parcels_revised_w_facilities_100m_w_industrial_fix_Nov22.gpkg") %>% 
  st_transform(4269) %>% 
  select(Stone_Unique_ID_revised, stat_land_comb = stat_land_)

parc.df <- parc.sf %>% st_drop_geometry()

nrow(parc.df)
nrow(distinct(parc.df, Stone_Unique_ID_revised))

# original parcels data
parc_orig <- st_read("data/LP_processed/Parcels_Revised_lookup_only_v2_fixed_geom.gpkg")
nrow(parc_orig)

# Lauren's original lookup table - for comparing results
fac_parc <- read_csv("data/LP_processed/facility_parcel_lookup_2022Jun8.csv")


# JOINING -----------------------------------------------------------------

class_1 <- fac_all.sf %>%
  st_join(parc.sf %>% filter(stat_land_comb == "F2"),
          join = st_intersects,
          left = FALSE)

class_1  %>% 
  group_by(latlon_merge_src) %>% 
  summarise(reg = n_distinct(registry_id), 
            stone = n_distinct(Stone_Unique_ID_revised))

count(class_1, latlon_merge_src)
filter(class_1, registry_id == 110000460901)
filter(fac_parc, registry_id == 110000460901)

filter(fac_parc, registry_id == 110000460910)

st_crs(parc.sf) == st_crs(fac_all.sf)

class_1_dist <- class_1 %>% st_drop_geometry() %>% distinct(registry_id)
nrow(class_1_dist)

fac_parc %>% 
  filter(uncertainty_class == 1) %>% 
  summarise(reg = n_distinct(registry_id), 
            stone = n_distinct(Stone_Unique_ID_revised))
  # anti_join(class_1_dist, by = "registry_id") %>% 
  # distinct(registry_id)
  # filter(registry_id == 110000460983)

# how many industrial parcels in my parcel dataset?
parc.sf %>% filter(stat_land_comb == "F2") %>% nrow()


# issue hunting

#1 - There are ~1,000 parcels in my original data which aren't in the new data
# original is from limiting the full parcel data to stone_ids which are in her lookup

# find parcels which are in original but not new restricted parcel data
parc_orig %>% anti_join(parc, by = "Stone_Unique_ID_revised") %>% select(Stone_Unique_ID_revised)

filter(fac_parc, Stone_Unique_ID_revised == 44660)
filter(fac_parc, registry_id  == 110009313331)
