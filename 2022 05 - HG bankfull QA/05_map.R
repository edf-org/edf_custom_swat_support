
## Purpose of script: 
## Map USGS gages and subbasins in study area included in bankfull QC analysis
## 
## Author: Greg Slater 
##
## Date Created: 2022-11-28
## ---------------------------

pacman::p_load(tidyverse, lubridate, paletteer, scales, sf)

source("src/edf_theme.R")
source("src/functions.R")
theme_set(theme_edf())


# DATA IN -----------------------------------------------------------------

# gages sf
gages_sf <- st_read("output/spatial/gages/USGS_study_area_gages.shp")


# read in subbasin sf and rivers sf
subs_sf <- st_read("data/spatial/subbasin/subs1_fixed.shp") %>%
  select(subbasin = Subbasin)

# rivers sf
rivs_sf <- st_read("data/spatial/riv1/riv1.shp") %>%
  select(subbasin = Subbasin)

# joined swat and usgs data
floods_swat_usgs %>% write_csv("output/floods_swat_usgs.csv")



# MAP OF SUBBASINS AND GAGES ----------------------------------------------

# subbasin ids for labels - take req. IDs from subs_sf and create centroids 
sub_labs <- subs_sf %>% 
  filter(subbasin %in% distinct(floods_swat_usgs, subbasin)$subbasin) %>%
  st_centroid()

# subbasin rivers - intersect rivers with only subbasins to be mapped
sub_rivs <- st_intersection(rivs_sf,
                            filter(subs_sf, subbasin %in% distinct(floods_swat_usgs, subbasin)$subbasin))

# sf of funny gages
funny_gages <- filter(gages_sf, site_no %in% {
  floods_swat_usgs %>% 
  filter(usgs_funny == 1) %>% 
  distinct(site_no) %>% 
  pull()
  })



# check subs and gages data intersects
m1 <- ggplot() +
  geom_sf(data = subs_sf, fill = NA, col = "grey80", alpha = .3, lwd = .1) +
  geom_sf(data = filter(subs_sf, subbasin %in% distinct(floods_swat_usgs, subbasin)$subbasin),
          fill = NA, lwd = .3) +
  geom_sf(data = sub_rivs, col = "steelblue", lwd = .5) +
  geom_sf(data = filter(gages_sf, site_no %in% distinct(floods_swat_usgs, site_no)$site_no),
          aes(col = station_nm),
          size = 2) +
  geom_sf(data = funny_gages, shape = 21, col = "red", fill = NA, size = 2, lwd = .5) +
  geom_sf_text(data = sub_labs, aes(label = subbasin), size = 3, alpha = .5) +
  coord_sf(datum = NA) +
  theme_edf() +
  theme(legend.position = "bottom", 
        legend.text = element_text(size=7),
        legend.spacing.y = unit(0.05, "cm"),
        axis.title = element_blank()) +
  guides(colour = guide_legend(ncol = 3, byrow = TRUE)) +
  labs(title = "Subbasins and Gages with data for QC", col = "")

m1
ggsave("figs/map_bankfull qc_subbasins gages_funnies flagged_v2.png", m1, units = "cm", height = 25, width = 20)
