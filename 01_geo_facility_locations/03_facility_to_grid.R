
## Purpose of script: 
## To use the facility > parcel lookup table to match facility locations to
## grid cells. Output is a facility > raster cell id lookup table, which also
## records the uncertainty_class (facility > parcel match quality)
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

# Lauren's facility to parcel lookup
f_parc <- read_csv("output/facilities/facility_parcel_lookup_2022-12-13.csv")

nrow(f_parc)
head(f_parc)

# read in raster template
rt <- read_stars("data/raster_template/raster_template.tif")

# read in parcels shapefile - these are the parcels identified in the facility > parcel lookup file
# (this was created by joining the csv in QGIS and exporting only joined parcels, to save reading full file in here)
parcels_sf <- st_read("output/parcels/parcels_lookup_only_20221213.gpkg") %>%
  st_transform(6587)

glimpse(parcels_sf)


# PARCEL DATA SENSE CHECKS -----------------------------------------------------

# PARCEL LOOKUP FILE

# Lauren's matching quality classes
f_parc %>% distinct(uncertainty_class, note)

# summarise n records by different IDs, without counting NAs
f_parc %>%
  summarise(n = n(),
            registry_id = n_distinct(registry_id[!is.na(registry_id)]),
            registry_stone_id = n_distinct(registry_stone_id),
            geo_id_revised = n_distinct(geo_id_revised[!is.na(geo_id_revised)]),
            Stone_Unique_ID_revised = n_distinct(Stone_Unique_ID_revised[!is.na(geo_id_revised)]))

f_parc %>% count(uncertainty_class)


# check what the highest number of facilities some parcels have matched to them is: 7
f_parc %>% 
  count(Stone_Unique_ID_revised) %>%
  arrange(desc(n))

# check what the highest number of parcels any facility is matched to: 182. Seems very high..
f_parc %>% 
  count(registry_id) %>%
  arrange(desc(n))

# but we can see most with many matches are links to any parcel (4.3) rather than commercial or vacant land (4.2)
f_parc %>% 
  count(registry_id, uncertainty_class) %>%
  arrange(desc(n))

# PARCEL SHAPEFILE
# count n distinct records in parcels sf
parcels_sf %>%
  st_set_geometry(NULL) %>%
  summarise(n_row = n(),
            #               n_registry_id = n_distinct(registry_i),
            n_Stone_Unique_ID_revised = n_distinct(Stone_Unique_ID_revised))



# SPATIAL JOINING ---------------------------------------------------------

# 1. Create a shapefile of all raster grid cells overlapping facility parcels
#    (this will be used to intersect with the parcel polygons)

# NB - simply rasterising the parcel data isn't good enough. Some grid cells have multiple parcels within, and rasterising
# loses this level of granularity, i.e. the raster cell becomes associated with just one of the parcels and we might lose
# the link back from a facility to the parcel which has been ignored.
# Instead, approach is to polygonise the grid cells we're interested in and then do a full intersection with the parcel
# data. That way the sometimes one to many relationship between grid cells and parcels can be retained.

# set raster values to NA
rt_na <- rt
rt_na[[1]][] <- NA

# rasterise parcel data to get the grid cells we're interested in
parcels_rast <- parcels_sf %>%
  select(Stone_Unique_ID_revised) %>%
  st_rasterize(template = rt_na, options = "ALL_TOUCHED=TRUE")

# convert rasterised parcels to a df (which has the grid_id)
# then convert this back to a raster using the grid_id as the attribute
parcels_rast_grid <- raster_to_df(parcels_rast) %>%
  filter(!is.na(value)) %>%
  csv_to_raster("cell_id", "cell_id", rt) %>%
  setNames("grid_id")

write_stars(parcels_rast_grid, "output/spatial/raster_clipped_to_parcels.tif")

# extract parcel raster cells as polygons and save as shapefile
parcels_rast_sf <- parcels_rast_grid[,] %>%
  st_as_sf(as_points = FALSE, merge = FALSE)

nrow(parcels_rast_sf)


# 2. Intersect raster grid cells (which overlap with parcels) with facility parcels

parc_grids_sf <- parcels_sf %>%
  select(Stone_Unique_ID_revised) %>%
  st_intersection(parcels_rast_sf) %>%  
  mutate(parcel_area_grid = as.numeric(st_area(geom)),
         grid_area_pct = parcel_area_grid / 10000)

# count no of parcels and grid cells that have been joined
parc_grids_sf %>% 
  st_drop_geometry() %>% 
  summarise(parcels = n_distinct(Stone_Unique_ID_revised),
            grids = n_distinct(grid_id),
            n = n())


# write output to check in QGIS
st_write(parc_grids_sf, "output/spatial/parcel_raster_cells_intersected.gpkg", delete_dsn = TRUE)

# 3. Join parcel grid polygons to the facility>parcel lookup

f_parc_grid_sf <- parc_grids_sf %>%
  inner_join(f_parc, by = "Stone_Unique_ID_revised")

glimpse(f_parc_grid_sf)

f_parc_grid_sf %>% 
  st_drop_geometry() %>% 
  summarise(parcels = n_distinct(Stone_Unique_ID_revised),
            grids = n_distinct(grid_id),
            n = n())

# save - not necessary, but this is useful to inspect the parcel/grid intersections and facility to 
# parcel links
# f_parc_grid_sf %>%
#   select(-c(fac_src, note, geo_id_revised, parcel_area_grid)) %>%
#   st_write("output/spatial/parcel_raster_cells_intersected_facility_joined.gpkg", delete_dsn = TRUE)

# 4. Dissolve geometries across facilites, grid_ids and uncertainty_class, and calculate area
# NB - This is necessary because some facilities are linked to multiple land parcels,
# with the same uncertainty class, and which overlap in the same grid cell.
# Groupig like this means for any facility, we'll get the grid area covered
# by any parcels in the same uncertainty class.

# note - this takes a few minutes to run
f_parc_grid_dissolved_sf <- f_parc_grid_sf %>% 
  select(-c(fac_src, note, geo_id_revised, parcel_area_grid)) %>%
  group_by(registry_stone_id, grid_id, uncertainty_class) %>% 
  summarize() 

nrow(f_parc_grid_dissolved_sf)
st_write(f_parc_grid_dissolved_sf, "output/spatial/parcel_raster_cells_intersected_facility_dissolved.gpkg", delete_dsn = TRUE)
f_parc_grid_dissolved_sf_orig <- st_read("output/spatial/parcel_raster_cells_intersected_facility_dissolved.gpkg")


f_parc_grid_dissolved_sf %>%
  st_drop_geometry() %>%
  ungroup() %>% 
  summarise(n_row = n(),
            # n_fac = n_distinct(registry_id),
            # n_stone = n_distinct(Stone_Unique_ID_revised),
            n_reg_stone = n_distinct(registry_stone_id),
            n_grids = n_distinct(grid_id))

f_grid_lookup <- f_parc_grid_dissolved_sf %>% 
  ungroup() %>% 
  mutate(grid_area_pct = as.numeric(st_area(geom)) / 10000) %>%
  st_drop_geometry()


# count rows, and check table is distinct across all fields 
nrow(f_grid_lookup)
nrow(f_grid_lookup) == nrow(f_grid_lookup %>% distinct())




# ADD IN NO-MATCH FACILITIES ----------------------------------------------

# these are 6 facilities which didn't match any parcels, so added just as nearest grid cell
no_match_facs <- read_csv("data/LP_processed/facilities_missing_parcels.csv") %>%
  rename(registry_stone_id = registry_id) %>%
  select(-Previous_Status , -LATITUDE83 , -LONGITUDE83) %>%
  mutate(uncertainty_class = 6)

# check they're not in the lookup already
no_match_facs %>% inner_join(f_grid_lookup, by = "registry_stone_id")

f_grid_lookup <- bind_rows(f_grid_lookup, no_match_facs)

# save
f_grid_lookup %>% write_csv(paste0("output/facilities/facility_grid_lookup_2.0_", today(), ".csv"))
# f_grid_lookup <- read_csv(paste0("output/facilities/facility_grid_lookup_2.0_", today(), ".csv"))

# counts of lookup file
f_grid_lookup %>% summarise(rows = n(),
                            registry_stone_id = n_distinct(registry_stone_id),
                            grid_id = n_distinct(grid_id))

# count by class 
f_grid_lookup %>%
  group_by(uncertainty_class) %>%
  summarise(n_facilities = n_distinct(registry_stone_id),
            n_grid_cells = n(),
            #               mean_area_pct = mean(area_grid_pct),
            total_area_km_2 = scales::comma(sum((grid_area_pct * 10000)) / 1000000, accuracy = 0.1)) %>% copyExcel()
