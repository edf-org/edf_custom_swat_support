

## Purpose of script: 
## Create a file of all facility location data for the Healthy Gulf project
## by combining data from original file (facilities_v2021Jul28_HUC8pts.shp) with new 
## data sourced by Cloelle (PROGbyFRS_uniq_11-21-22.csv)
## 
## Author: Greg Slater 
##
## Date Created: 2022-11-22


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
  mutate(fac_src = "facilities_20220311.csv",
         latlon_src = "facilities_20220311.csv",
         LATITUDE83 = as.double(LATITUDE83),
         LONGITUDE83 = as.double(LONGITUDE83),
         FAC_ACCURACY = as.double(FAC_ACCURACY))

fac_orig.sf <- fac_orig.df %>% 
  filter(!is.na(Latitude)) %>% 
  st_as_sf(coords = c("Longitude", "Latitude"), crs=4326, remove = F)


# read in new facilities data from Cloelle
fac_new <- read_csv("data/facilities/PROGbyFRS_uniq_11-21-22.csv")

# study area boundary
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

# Study area clip
# --- --- --- ---

# create an sf of results
gc_results.sf <- results_wide %>% 
  filter(!is.na(lat)) %>% 
  st_as_sf(coords = c("lng", "lat"), crs=4326, remove = F)

# clip results to study area by intersecting
gc_results_clip.sf <- gc_results.sf %>% 
  st_intersection(study_area.sf, left = F)

gc_results_clip.df <- gc_results_clip.sf %>% 
  st_drop_geometry()

nrow(gc_results_clip.df)
nrow(gc_dist_comparison)

# Join geocoded results with other new data
# --- --- --- ---

# edit names to match original data, or make geocoding source clear
fac_new_clip_coded <- fac_new_clip %>% 
  inner_join(gc_results_clip.df, by = "REGISTRY_ID") %>% 
  mutate(fac_src = "PROGbyFRS_uniq_11-21-22.csv",
         Latitude = lat,
         Longitude = lng,
         latlon_src = "Google geocoding API - GS") %>% 
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
         ) %>% 
  left_join(gc_dist_comparison %>% select(REGISTRY_ID, distance), by = "REGISTRY_ID") %>% 
  mutate(distance = as.numeric(distance) / 1000) %>% 
  rename(fac_orig_new_dist_km = distance)

fac_new_clip_coded %>% count(GC_geocode_attempt, latlon_src)
nrow(fac_new_clip_coded)

# create list of common fields between original and new datasets - use for full join
common_fields <- inner_join(tibble("names" = names(fac_orig.df)),
                            tibble("names" = names(fac_new_clip_coded))) %>% pull(names)


# join all data
fac_all.df <- fac_orig.df %>% 
  full_join(fac_new_clip_coded, by = common_fields) #%>% 
  # mutate(lat_merge = ifelse(is.na(lat_merge), GC_lat, lat_merge),
  #        lon_merge = ifelse(is.na(lon_merge), GC_lng, lon_merge))



# count data and location sources in file to check structure makes sense
fac_all.df %>% count(fac_src, latlon_src, GC_geocode_attempt, is.na(Latitude))

# how many facilities, and distinct by registry_id?
nrow(fac_all.df)
nrow(fac_all.df %>% distinct(REGISTRY_ID))

# check nrows of full joined table = orig + new 
nrow(fac_orig.df) + nrow(fac_new_clip_coded) == nrow(fac_all.df)

# write_csv(fac_all.df, paste0("output/facilities/facilities_all_coded_", today(), ".csv"))


glimpse(fac_all.df)



# FACILITY OVERLAPS -------------------------------------------------------

# find and count duplicate points in the original data

fac_orig.sf %>% as.data.frame() %>% #glimpse()
  select(REGISTRY_ID, PRIMARY_NAME, LOCATION_ADDRESS, geometry) %>% 
  mutate(geometry = as.character(geometry)) %>% 
  group_by(geometry) %>% 
  mutate(sum = n()) %>% 
  # filter(sum > 1) %>% 
  arrange(geometry) %>% 
  ungroup() %>% 
  count(sum) %>% 
  mutate(pct = n / sum(n)) %>% copyExcel()


# find and count duplicate points in the updated data with all facilities

fac_all.sf <- fac_all.df %>%
  filter(!is.na(Latitude)) %>% 
  st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326)


fac_all.sf %>% as.data.frame() %>% 
  select(REGISTRY_ID, PRIMARY_NAME, LOCATION_ADDRESS, geometry) %>% 
  mutate(geometry = as.character(geometry)) %>% 
  group_by(geometry) %>% 
  mutate(sum = n()) %>% 
  # filter(sum > 1) %>%
  # arrange(geometry) %>% write_csv("output/facilities/facilities_duplicated_locations.csv")
  ungroup() %>% 
  count(sum) %>% 
  mutate(pct = n / sum(n)) #%>% copyExcel()

# count and write to csv, retaining the registry_id
fac_all.sf %>% as.data.frame() %>% 
  select(REGISTRY_ID, PRIMARY_NAME, LOCATION_ADDRESS, ZIP_CODE, latlon_src, geometry) %>% 
  mutate(geometry = as.character(geometry)) %>% 
  group_by(geometry) %>% 
  mutate(n_fac_overlaps = n()) %>% 
  ungroup() %>% 
  # filter(sum > 1) %>%
  arrange(desc(n_fac_overlaps), geometry, REGISTRY_ID) %>% 
  write_csv("output/facilities/facilities_duplicated_locations.csv")


fac_all.df %>% 
  mutate(point_orig = sf::st_linestring(x = matrix(c(LONGITUDE83, Longitude, LATITUDE83, Latitude), 
                                                   nrow = 2, 
                                                   ncol = 2)))

fac_all.df$dist_linestring <- sprintf("LINESTRING(%s %s, %s %s)", 
                                      fac_all.df$LONGITUDE83, 
                                      fac_all.df$LATITUDE83, 
                                      fac_all.df$Longitude, 
                                      fac_all.df$Latitude)

fac_all.df %>% 
  filter(!is.na(LATITUDE83), !is.na(Latitude)) %>% 
  write_csv(paste0("output/facilities/facilities_all_coded_wlinestring", today(), ".csv"))

fac_all.df %>% count(latlon_src, is.na(Latitude))
