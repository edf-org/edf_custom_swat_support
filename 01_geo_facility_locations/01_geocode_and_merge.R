

## Purpose of script: 
## Create a file of all facility location data for the Healthy Gulf project
## by combining data from original file (facilities_v2021Jul28_HUC8pts.shp) with new 
## data sourced by Cloelle (PROGbyFRS_uniq_11-21-22.csv)
## 
## Author: Greg Slater 
##
## Date Created: 2022-11-22
## ---------------------------

## load up packages

pacman::p_load(tidyverse, lubridate, RColorBrewer, scales, sf, jsonlite, httr, geosphere, units)

source("src/edf_theme.R")
source("src/functions.R")
theme_set(theme_edf())



# DATA IN ---------------------------------------------------------------

# read in original facilities data
# this is RJ's final file, after geocoding all facilities using their address info
# the lcation of facilities after geocoding is in the 'Latitude' and 'Longitude' fields
fac_orig.df <- read_csv("data/facilities/from RJ/facilities_20220311.csv") %>% 
  rename(REGISTRY_ID = REGISTRY_I,
         LOCATION_ADDRESS = LOCATION_A,
         PRIMARY_NAME = PRIMARY_NA,
         FAC_ACCURACY = FAC_ACCURA,
         FAC_REFERENCE = FAC_REFERE,
         LONGITUDE83 = LONGITUDE8,
         COUNTY_NAME = COUNTY_NAM) %>% 
  mutate(fac_source = "facilities_20220311.csv",
         latlon_src = "facilities_20220311.csv",
         LATITUDE83 = as.double(LATITUDE83),
         LONGITUDE83 = as.double(LONGITUDE83),
         FAC_ACCURACY = as.double(FAC_ACCURACY))


# # read in original facilities data and project to NAD83
# fac_orig.sf <- st_read("data/facilities/facilities_v2021Jul28_HUC8pts/facilities_v2021Jul28_HUC8pts.shp",
#                        stringsAsFactors = F) %>% 
#   st_transform(4269) %>% 
#   rename(REGISTRY_ID = REGISTRY_I,
#          LOCATION_ADDRESS = LOCATION_A,
#          PRIMARY_NAME = PRIMARY_NA,
#          FAC_ACCURACY = FAC_ACCURA,
#          FAC_REFERENCE = FAC_REFERE,
#          LONGITUDE83 = LONGITUDE8,
#          COUNTY_NAME = COUNTY_NAM) %>% 
#   mutate(edf_source = "facilities_v2021Jul28_HUC8pts.shp",
#          latlon_merge_src = "facilities_v2021Jul28_HUC8pts.shp",
#          LATITUDE83 = as.double(LATITUDE83),
#          LONGITUDE83 = as.double(LONGITUDE83),
#          FAC_ACCURACY = as.double(FAC_ACCURACY))
# 
# fac_orig.df <- fac_orig.sf %>% st_drop_geometry()


fac_new <- read_csv("data/facilities/PROGbyFRS_uniq_11-21-22.csv")

study_area.sf <- st_read("data/study_area_census_dissolve.gpkg") %>% 
  st_transform(4326)

# SENSE CHECKS ---------------------------------------------------------------

# check what how many records and if REGISTRY_ID is unique
nrow(fac_orig.df)
nrow(fac_orig.df) == nrow(fac_orig.df %>% distinct(REGISTRY_ID))

nrow(fac_new)
nrow(fac_new) == nrow(fac_new %>% distinct(REGISTRY_ID))

glimpse(fac_new)

# how many facilites cross over or not between tables
nrow(inner_join(fac_new, fac_orig.df, by = "REGISTRY_ID"))
nrow(anti_join(fac_new, fac_orig.df, by = "REGISTRY_ID"))

# create table of the actually new facilities
fac_new_clip <- fac_new %>% 
  anti_join(fac_orig.df, by = "REGISTRY_ID")

# how many of the new facilities are missing location data?
fac_new_clip %>% 
  filter(is.na(LATITUDE83)) %>% 
  nrow()

# write_csv(fac_new_clip, "data/facilities/facilities_new_nodupes.csv")

# create sf of new facilities and transform to WGS84
fac_new.sf <- fac_new_clip %>% 
  filter(!is.na(LATITUDE83)) %>% 
  st_as_sf(coords = c("LONGITUDE83", "LATITUDE83"), crs=4269, remove = F) %>% 
  st_transform(4326)

# save df with WGS84 location data - we want this later to compare to the geocoding results
fac_new.df <- fac_new.sf %>%
  mutate(lon_orig_wgs84 = sf::st_coordinates(.)[,1],
         lat_orig_wgs84 = sf::st_coordinates(.)[,2]) %>% 
  st_drop_geometry()

# plot of new facilities and study area
ggplot() +
  geom_sf(data = study_area.sf, fill = NA) +
  geom_sf(data = fac_new.sf, col = "red", size = 1) +
  coord_sf(datum = NA) +
  theme_minimal()


# GEOCODING ---------------------------------------------------------------


BASE_URL <- "https://maps.googleapis.com/maps/api/geocode/json?"
KEY <- "INSERT_KEY"

# function to hit google geocoding API
# bounds option doesn't give hard limit but just biases
# see: https://developers.google.com/maps/documentation/geocoding/
geoCode <- function(address){
  
  resp <- GET(BASE_URL, 
           query = list(address = address, 
                        bounds = "28.97004,-95.98899|30.77386,-94.14137",
                        key = KEY)
  )
  
  if (http_type(resp) != "application/json") {
    stop("API did not return json", call. = FALSE)
  }
  
  content(resp, "text") %>% fromJSON(simplifyDataFrame = T)
  
}


# test single one
address <- "6287 GULFWAY DRIVE 77619-4220"
j <- geoCode(address)

# check pulling out key info
j[[1]]$address_components[[1]]
j[[1]]$formatted_address
j[[1]]$geometry$location$lat
j[[1]]$geometry$location$lng




# list of facilities to geocode: all new facilities
# also, get rid of NAS in postcode and create short version with key 5 digits
to_code <- fac_new_clip %>% 
  mutate(POSTAL_CODE = replace_na(POSTAL_CODE, ""),
         pcode_short = str_sub(POSTAL_CODE, 1, 5))


results.df <- NULL

for (i in 1:nrow(to_code)){
# for (i in 1:2){
  
  # create string address from location + postcode
  address <- paste(to_code$LOCATION_ADDRESS[i],
                   to_code$pcode_short[i])
  

  resp <- geoCode(address)
  
  if (resp$status == "OK"){
    
    # pull out lists of values and fields from the response address_components list
    # these will be name and value lists of different lengths per response
    addr_values <- resp[["results"]][["address_components"]][[1]][["long_name"]]
    addr_fields <- sapply(resp[["results"]][["address_components"]][[1]][["types"]], function(x) x[1])
    
    # create longer fields and values lists by adding in formatted add., lat & lng
    fields <- c(addr_fields, "formatted_address", "lat", "lng", "location_type", "geocode_result")
    values <- c(addr_values, 
                resp[[1]]$formatted_address[1],
                resp[[1]]$geometry$location$lat[1],
                resp[[1]]$geometry$location$lng[1],
                resp[[1]]$geometry$location_type[1],
                "success")
    
  } else{
    
    # if error, the only field to save is the result: erro
    fields <- "geocode_result"
    values <- "error"
  }
  
  # proceed if pulling back fields and values has worked and they're the same length
  if (length(fields) == length(values)){
    # stick in df
    df <- data.frame("REGISTRY_ID" = to_code$REGISTRY_ID[i],
                     "field" = fields,
                     "value" = values,
                     stringsAsFactors = FALSE)
  } else {
    # otherwise create another error
    df <- data.frame("REGISTRY_ID" = to_code$REGISTRY_ID[i],
                     "field" = "geocode_result",
                     "value" = "multiple responses",
                     stringsAsFactors = FALSE)
  }
  
  # bind to results
  results.df <- bind_rows(results.df, df)
  
  # print progress and save every 50 records
  if (i%%50 == 0){
    print(paste0("Geocoded ", i, " out of ", nrow(to_code), " records"))
    write_csv(results.df, "output/geocoding/geocoding_results_narrow.csv")
  }
}

# write_csv(results.df, "output/geocoding/geocoding_results_narrow.csv")

# pivot results and save
results_wide <- results.df %>% 
  filter(field %in% c("geocode_result", "location_type", "postal_code", "formatted_address", "lat", "lng")) %>% 
  pivot_wider(names_from = field, values_from = value) %>% 
  mutate(geocode_attempt = 1,
         lat = as.double(lat),
         lng = as.double(lng))

# write_csv(results_wide, "output/geocoding/geocoding_results_wide.csv")
# results_wide <- read_csv("output/geocoding/geocoding_results_wide.csv")


# GEOCODING RESULTS --------------------------------------------------

# inspect errors - just two which have bad input address data
errors <- filter(results.df, field == "geocode_result" & value != "success") %>% 
  inner_join(to_code)

nrow(results_wide)

count(results_wide, location_type) %>% mutate(pct = n/sum(n)) %>% copyExcel()
count(results_wide, geocode_result)


# results_comb <- results_wide %>% 
#   inner_join(to_code, by = "REGISTRY_ID")

# calculate distance between original points and new geocoded results
# for 6 facilities this is > 190km
gc_dist_comparison <- results_wide %>% 
  inner_join(fac_new.df, by = "REGISTRY_ID") %>% 
  group_by(REGISTRY_ID) %>% 
  mutate(distance = set_units(distGeo(c(lng, lat), c(lon_orig_wgs84, lat_orig_wgs84)), m))

gc_dist_comparison %>% filter(as.numeric(distance) <= 10000) %>% nrow() / nrow(gc_dist_comparison)

# plot distribution of point movement (excluding really big jumps)
fig_dist <- ggplot(gc_dist_comparison %>% 
         filter(as.numeric(distance) / 1000 < 190), 
       aes(as.numeric(distance) / 1000)) + 
  geom_histogram(fill = "steelblue") +
  scale_x_continuous(breaks = seq(0, 60, 10)) +
  labs(title = "Facility point movement post-geocoding",
       subtitle = "Comparison for 486 of the 569 new facilities with location data",
       x = "Distance (Km)", y = "n facilities")

ggsave("figs/fig - facility point movement post-geocoding.png", fig_dist, units = "cm", width = 15, height = 7)



# FORMATTING AND MERGING --------------------------------------------------


# NEXT STEPS
# - restrict results to study area
# - merge to one file, including distance



# The geocoded results are in WGS84 - so need to be converted to NAD83 before merging with original data
# --- --- --- ---

# create sf from geocoded results (with WGS84 coords) and re-project to NAD83
results.sf <- results_wide %>% 
  filter(geocode_result == "success") %>% 
  st_as_sf(coords = c("lng", "lat"), crs = 4326) %>% 
  st_transform(4269)

# extract NAD83 coords from df
results_4269.df <- results.sf %>%
  mutate(lng = sf::st_coordinates(.)[,1],
         lat = sf::st_coordinates(.)[,2]) %>% 
  st_drop_geometry()

# replace the geocoded lat lng with NAD83 coords
results_wide_4269 <- results_wide %>% 
  select(-c(lat, lng)) %>% 
  left_join(results_4269.df %>% select(REGISTRY_ID, lat, lng), by = "REGISTRY_ID")



# Join geocoded results with other new data
# --- --- --- ---

# edit names to match original data, or make geocoding source clear
fac_new_clip_coded <- fac_new_clip %>% 
  left_join(results_wide_4269, by = "REGISTRY_ID") %>% 
  mutate(edf_source = "PROGbyFRS_uniq_11-21-22.csv - where registry_id is not in facilities_v2021Jul28_HUC8pts.shp",
         lat_merge = ifelse(is.na(LATITUDE83), lat, LATITUDE83),
         lon_merge = ifelse(is.na(LONGITUDE83), lng, LONGITUDE83),
         latlon_merge_src = ifelse(is.na(LATITUDE83), "Google geocoding API - GS", "PROGbyFRS_uniq_11-21-22.csv")) %>% 
  rename(ZIP_CODE = POSTAL_CODE,
         FAC_ACCURACY = ACCURACY_VALUE,
         FAC_REFERENCE = REF_POINT_DESC,
         GC_postal_code = postal_code,
         GC_location_address = formatted_address,
         GC_location_type = location_type,
         GC_geocode_result = geocode_result,
         GC_geocode_attempt = geocode_attempt,
         GC_lat = lat,
         GC_lng = lng
         )

fac_new_clip_coded %>% count(GC_geocode_attempt, latlon_merge_src)

# create list of common fields between original and new datasets - use for full join
common_fields <- inner_join(tibble("names" = names(fac_orig.df)),
                            tibble("names" = names(fac_new_clip_coded))) %>% pull(names)

# fac_all.df <- read_csv("output/facilities/facilities_all_coded_2022-11-23.csv", guess_max = 2000)

# join all data
fac_all.df <- fac_orig.df %>% 
  full_join(fac_new_clip_coded, by = common_fields) %>% 
  mutate(lat_merge = ifelse(is.na(lat_merge), GC_lat, lat_merge),
         lon_merge = ifelse(is.na(lon_merge), GC_lng, lon_merge))

# count data and location sources in file to check structure makes sense
fac_all.df %>% count(edf_source, latlon_merge_src, GC_geocode_attempt, is.na(lat_merge))

nrow(fac_all.df)
nrow(fac_all.df %>% distinct(REGISTRY_ID))

# check nrows of full joined table = orig + new 
nrow(fac_orig.df) + nrow(fac_new_clip_coded) == nrow(fac_all.df)

# write_csv(fac_all.df, paste0("output/facilities/facilities_all_coded_", today(), ".csv"))


glimpse(fac_all.df)

# Geocoding quirks investigation
# --- --- --- ---

# take a look at some facilities where the source zip code doesn't match the geocoded
# from a couple of spot checks these either seem to be instances where the geocoding is fine
# and the zipcode is the next one along to the source one, or where the geocoding result is 
# approximate because of poor input information.
fac_new_clip_coded %>% filter(ZIP_CODE != postal_code) %>% 
  select(PRIMARY_NAME, FAC_REFERENCE, ZIP_CODE, postal_code, LOCATION_ADDRESS, formatted_address, location_type) %>% view()

glimpse(fac_orig.df)

resp <- geoCode("12585 N BAMMEL HOUSTON 77066")


  
# fac_orig.df <- fac_orig.sf %>%
#   mutate(lon = sf::st_coordinates(.)[,1],
#          lat = sf::st_coordinates(.)[,2]) %>% 
#   st_drop_geometry()
# 
# fac_orig.df %>% 
#   mutate(lat_dif = lon - lon_merge) %>% 
#   arrange(desc(lat_dif))


# find duplicate points

fac_orig.sf %>% as.data.frame() %>% #glimpse()
  select(REGISTRY_ID, PRIMARY_NAME, LOCATION_ADDRESS, geometry) %>% 
  mutate(geometry = as.character(geometry)) %>% 
  group_by(geometry) %>% 
  mutate(sum = n()) %>% 
  filter(sum > 1) %>% 
  arrange(geometry) %>% 
  ungroup() %>% count(sum) %>% copyExcel()

80 / 946

fac_new_clip_coded.sf <- fac_new_clip_coded %>%
  filter(!is.na(lat_merge)) %>% 
  st_as_sf(coords = c("lon_merge", "lat_merge"), crs = 4269)


fac_new_clip_coded.sf %>% as.data.frame() %>% 
  select(REGISTRY_ID, PRIMARY_NAME, LOCATION_ADDRESS, geometry) %>% 
  mutate(geometry = as.character(geometry)) %>% 
  group_by(geometry) %>% 
  mutate(sum = n()) %>% 
  filter(sum > 1) %>% 
  arrange(geometry) %>%
  ungroup() %>% count(sum)


st_join(fac_orig.sf, fac_new_clip_coded.sf, join = st_contains) %>% 
  st_drop_geometry() %>% 
  distinct(REGISTRY_ID.x)


fac_orig.sf[st_intersects(fac_orig.sf, fac_new_clip_coded.sf), ]

fac_new_clip_coded.sf[which(unlist(st_intersects(fac_orig.sf, fac_new_clip_coded.sf)) == 1)]

66/569

fac_all.sf <- fac_all.df %>%
  filter(!is.na(lat_merge)) %>% 
  st_as_sf(coords = c("lon_merge", "lat_merge"), crs = 4269)


fac_all.sf %>% as.data.frame() %>% 
  select(REGISTRY_ID, PRIMARY_NAME, LOCATION_ADDRESS, geometry) %>% 
  mutate(geometry = as.character(geometry)) %>% 
  group_by(geometry) %>% 
  mutate(sum = n()) %>% 
  filter(sum > 1) %>%
  arrange(geometry) %>% write_csv("output/facilities/facilities_duplicated_locations.csv")
  # ungroup() %>% count(sum) %>% copyExcel()

163/1515
