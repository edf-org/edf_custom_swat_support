
## Purpose of script: 
## To match facility locations to land parcels in the study area and classify
## the quality of the matching. Output is a facility > parcel lookup table.
## 
## Author: Greg Slater 
##
## Date Created: 2022-11-22

## load up packages

pacman::p_load(tidyverse, lubridate, RColorBrewer, scales, sf, stars)

source("src/edf_theme.R")
source("src/functions.R")
theme_set(theme_edf())


# DATA IN ---------------------------------------------------------------

# all facilities data
fac_all.df <- read_csv("data/facilities/PROGbyFRS_uniq_051223_all_locations_V2.csv", guess_max = 2000) %>% 
  rename(registry_id = REGISTRY_ID, Latitude = Best_Latitude83, Longitude = Best_Longitude83)

nrow(fac_all.df)

fac_all.sf <- fac_all.df %>% 
  filter(!is.na(Latitude)) %>% 
  st_as_sf(coords = c('Longitude', 'Latitude'), crs=4326) %>% 
  st_transform(6587) %>% 
  select(registry_id)


# parcels data - limited (in QGIS) to just those within 100m of facilities, or with industrial land use
parc.sf <- st_read("data/parcels/parcels_revised_facilities100m_industrial_Dec22.gpkg") %>% 
  st_transform(6587) %>% 
  select(Stone_Unique_ID_revised, 
         geo_id_revised = geo_id,
         stat_land_comb = stat_land_)

# create df of parcels data
parc.df <- parc.sf %>% 
  st_drop_geometry()

nrow(parc.df)
nrow(distinct(parc.df, Stone_Unique_ID_revised))


# Lauren's original lookup table - for comparing results
f_parc <- read_csv("data/LP_processed/facility_parcel_lookup_2022Jun8.csv") %>% 
  mutate(registry_stone_id = ifelse(is.na(registry_id), 
                                    Stone_Unique_ID_revised,
                                    registry_id))

# count number of facilities and parcels by uncertainty class in original lookup
f_parc %>% group_by(uncertainty_class) %>% 
  summarise(fac = n_distinct(registry_id),
            parc = n_distinct(Stone_Unique_ID_revised),
            n = n())

# checking dupes in classes 1-3 in original lookup
f_parc %>% filter(uncertainty_class < 4) %>% distinct(registry_id) %>% nrow()

f_parc %>% 
  filter(uncertainty_class < 4) %>% 
  distinct(registry_id, uncertainty_class) %>% 
  count(registry_id) %>% 
  filter(n>1) %>% arrange(desc(n))


f_parc %>% filter(registry_id == 110000460787)
nrow(f_parc)


# JOINING -----------------------------------------------------------------

# CLASSES 1, 2, AND 3

# intersect facilities and parcels, then flag uncertainty class using the land use type from parcels 
class_123 <- fac_all.sf %>% 
  st_join(parc.sf,
          join = st_intersects,
          left = FALSE) %>% 
  mutate(uncertainty_class = case_when(stat_land_comb == "F2" ~ 1,
                                       stat_land_comb %in% c("C1", "C2", "C3", "C4", "F1") ~ 2,
                                       TRUE ~ 3)) %>% 
  st_drop_geometry()


# join to minimum uncertainty class to get rid of duplicates across classes
class_123_min <- class_123 %>% 
  group_by(registry_id) %>% 
  summarise(uncertainty_class = min(uncertainty_class)) %>% 
  inner_join(class_123, by = c("registry_id", "uncertainty_class"))

# is registry id unique across uncertainty classes?
distinct(class_123_min, registry_id) %>% 
  nrow() == distinct(class_123_min, registry_id, uncertainty_class) %>% 
  nrow()

# count results
class_123_min %>% 
  group_by(uncertainty_class) %>% 
  summarise(facilities = n_distinct(registry_id), 
            parcels = n_distinct(Stone_Unique_ID_revised))


# list of 1, 2, 3 facilities to join against
fac_123s <- class_123_min %>% 
  distinct(registry_id)


# CLASSES 4.1, 4.2, 4.3

# remove all 1, 2, and 3 matches from facilities, buffer 100m and then join to parcels
class_4 <- fac_all.sf %>% 
  anti_join(class_123 %>% distinct(registry_id), 
            by = "registry_id") %>% 
  st_buffer(100) %>% 
  st_join(parc.sf,
          join = st_intersects,
          left = FALSE) %>% 
  mutate(uncertainty_class = case_when(stat_land_comb == "F2" ~ 4.1,
                                       stat_land_comb %in% c("C1", "C2", "C3", "C4", "F1") ~ 4.2,
                                       TRUE ~ 4.3)) %>% 
  st_drop_geometry()

# count results
class_4 %>% 
  group_by(uncertainty_class) %>% 
  summarise(facilities = n_distinct(registry_id), 
            parcels = n_distinct(Stone_Unique_ID_revised))

# combine classes 1-4 to use as exclusion below
class_1234 <- bind_rows(class_123_min, class_4)


# CLASS 5

# here we just want the remaining industrial parcels which don't have a match already

# take just industrial parcels, remove any with existing class 1-4 matches, add new fields
class_5 <- parc.df %>% 
  filter(stat_land_comb == "F2") %>% 
  anti_join(class_1234 %>% distinct(Stone_Unique_ID_revised),
            by = "Stone_Unique_ID_revised") %>% 
  mutate(registry_id = NA,
         uncertainty_class = 5)
  

# ALL CLASSES

# bind all together and create combined registry_stone_id, for class 5 parcels
# which don't have a registry_id, and join on the class note from original table
class_all <- bind_rows(class_1234, class_5) %>% 
  mutate(registry_stone_id = ifelse(is.na(registry_id), 
                                    Stone_Unique_ID_revised,
                                    registry_id)) %>% 
  inner_join(f_parc %>% distinct(uncertainty_class, note),
             by = "uncertainty_class")

# export
# class_all %>% write_csv(paste0("output/facilities/facility_parcel_lookup_", today(), ".csv"))

# save geo file of parcels which are in the lookup
# parc.sf %>% 
#   inner_join(class_all %>% distinct(Stone_Unique_ID_revised),
#              by = "Stone_Unique_ID_revised") %>% 
#   st_write("output/parcels/parcels_lookup_only_2022-12-13.gpkg", delete_dsn = TRUE)


# count all by classes
class_all %>% 
  group_by(uncertainty_class) %>%
  summarise(facilities = n_distinct(registry_id), 
            parcels = n_distinct(Stone_Unique_ID_revised),
            n = n())

# comparison of orig lookup table
f_parc %>% 
  group_by(uncertainty_class) %>% 
  summarise(facilities = n_distinct(registry_id), 
            parcels = n_distinct(Stone_Unique_ID_revised),
            n = n())


# check records which don't match between new process and Lauren's original lookup

# in new but not in old

#new_not_old <- class_all %>% 
  #filter(fac_src == "facilities_20220311.csv" | is.na(fac_src)) %>% 
  #anti_join(f_parc, by = c("registry_stone_id", "uncertainty_class")) #%>% 
  # count(uncertainty_class, stat_land_comb)

# write_csv(new_not_old, "output/facilities/facility_parcel_lookup_new_not_old.csv")

# in old but not in new

#old_not_new <- f_parc %>% 
  #anti_join(class_all, by = c("registry_stone_id", "uncertainty_class")) %>% 
  #group_by(uncertainty_class) %>% 
  #count(uncertainty_class)
  # summarise(parcels = n_distinct(Stone_Unique_ID_revised)) %>% copyExcel()

write_csv(f_parc, "output/facilities/facility_parcel_lookup_2023_17_07.csv")

