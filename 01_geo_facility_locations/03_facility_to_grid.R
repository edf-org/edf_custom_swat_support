
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
f_parc <- read_csv("output/facilities/facility_parcel_lookup_2022-12-08.csv")

nrow(f_parc)
head(f_parc)

# read in raster template
rt <- read_stars("data/raster_template/raster_template.tif")

# read in parcels shapefile - these are the 10,278 parcels identified in Lauren's (inital) lookup
# (this was created by joining the csv in QGIS and exporting only joined parcels, to save reading full file in here)
parcels_sf <- st_read("output/parcels/parcels_lookup_only_20221208.gpkg") %>%
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
            geo_id_revised = n_distinct(geo_id_revised[!is.na(geo_id_revised)]),
            Stone_Unique_ID_revised = n_distinct(Stone_Unique_ID_revised[!is.na(geo_id_revised)]))

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
            n_Stone_Unique_ID_revised = n_distinct(lookup_Stone_Unique_ID_revised))



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

# write_stars(parcels_rast_grid, "output/spatial/raster_clipped_to_parcels.tif")

# extract parcel raster cells as polygons and save as shapefile
parcels_rast_sf <- parcels_rast_grid[,] %>%
  st_as_sf(as_points = FALSE, merge = FALSE)

nrow(parcels_rast_sf)
# st_write(parcels_rast_sf, "output/spatial/parcel_raster_cell_polys.gpkg")


# 2. Intersect raster grid cells (which overlap with parcels) with facility parcels

parc_grids_sf <- parcels_sf %>%
  select(Stone_Unique_ID_revised = lookup_Stone_Unique_ID_revised) %>%
  st_intersection(parcels_rast_sf) %>%  
  mutate(parcel_area_grid = as.numeric(st_area(geom)),
         grid_area_pct = parcel_area_grid / 10000)

# write output to check in QGIS
# st_write(parc_grids_sf, "output/spatial/parcel_raster_cells_intersected.gpkg", delete_dsn = TRUE)

# 3. Join parcel grid polygons to the facility>parcel lookup

# join and also create new `registry_stone_id` field for where the stone parcel id is missing 
f_parc_grid_sf <- parc_grids_sf %>%
  inner_join(f_parc, by = "Stone_Unique_ID_revised") %>%
  mutate(registry_stone_id = ifelse(is.na(registry_id), Stone_Unique_ID_revised, registry_id))

glimpse(f_parc_grid_sf)
# st_write(f_parc_grid_sf, "output/spatial/parcel_raster_cells_intersected_facility_joined.gpkg", delete_dsn = TRUE)

# 4. Dissolve geometries across facilites, grid_ids and uncertainty_class
# NB - This is necessary because some facilities are linked to multiple land parcels,
# with the same uncertainty class, and which overlap in the same grid cell.
# Groupig like this means for any facility, we'll get the grid area covered
# by any parcels in the same uncertainty class.

f_parc_grid_dissolved_sf <- f_parc_grid_sf %>% 
  group_by(registry_stone_id, grid_id, uncertainty_class) %>% 
  summarize()

nrow(f_parc_grid_dissolved_sf)
# st_write(f_parc_grid_dissolved_sf, "output/spatial/parcel_raster_cells_intersected_facility_dissolved.gpkg", delete_dsn = TRUE)


f_parc_grid_dissolved_sf %>%
  st_set_geometry(NULL) %>%
  ungroup() %>% 
  summarise(n_row = n(),
            # n_fac = n_distinct(registry_id),
            # n_stone = n_distinct(Stone_Unique_ID_revised),
            n_reg_stone = n_distinct(registry_stone_id),
            n_grids = n_distinct(grid_id))


parc <- read_csv("data/parcels/parcels_revised_w_facilities_100m_w_industrial_Nov22.csv")

glimpse(parc)
