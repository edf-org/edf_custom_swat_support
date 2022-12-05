
## Purpose of script: 
## Plot timeseries charts to compare SWAT bankfull % with USGS flood %
## 
## Author: Greg Slater 
##
## Date Created: 2022-11-20
## ---------------------------

## load up packages
pacman::p_load(tidyverse, lubridate, paletteer, scales, dataRetrieval, sf)

source("src/edf_theme.R")
source("src/functions.R")
theme_set(theme_edf())


# DATA IN -----------------------------------------------------------------

subs_sf <- st_read("data/spatial/subbasin/subs1_fixed.shp") %>%
  select(Subbasin)


# read in gages txt file
gages <- read_delim("data/USGS/usgs_gages_120302_1204.txt", ",") %>%
  mutate(site_no = paste0("0", as.character(site_no)))

# turn into sf
gages_sf <- st_as_sf(gages, coords = c('dec_long_va', 'dec_lat_va'), crs=4269) %>%
  st_transform(6587) %>%
  select(site_no, station_nm)


# CHARTS ------------------------------------------------------------------

# produce modelled (all four model runs) vs. monitored flow for each gage

chart_sites <- floods_swat_usgs_clean %>%
  filter(usgs_funny == 0) %>% 
  distinct(subbasin, site_no, station_nm)

chart_sites$site_no[2]

for (s in 1:nrow(chart_sites)){
# for (s in 1:1){
  
  data <- filter(floods_swat_usgs_clean, site_no == chart_sites$site_no[s])
  
  plot <- ggplot(data) +
    geom_line(aes(x = date, y = swat_flood_pct, color = "SWAT_bankfull_pct"), alpha = .5, lwd = .3) +
    geom_line(aes(x = date, y = usgs_flood_pct, color = "USGS_flood_pct"), lwd = .3) +
    
    geom_hline(yintercept = 1, col = "grey80", linetype = "dashed", lwd = .3) +
    
    scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    
    facet_wrap(vars(model_info), ncol = 1) +
    labs(title = chart_sites$station_nm[s],
         subtitle = paste0("Site no: ", chart_sites$site_no[s], "\n", "Subbasin: ", chart_sites$subbasin[s]),
         color = "", x = "Date", y = "Gage height\n(% of minor flood stage)")
  

  ggsave(paste0("figs/usgs_swat_comp_models/floods_usgs_swat_", chart_sites$site_no[s], ".png"),
         plot,
         units = "cm",
         height = 18,
         width = 25)
}


# map


reg_map_gages_sf <- gages_sf %>%
  inner_join(reg_scores, by = "site_no") %>% 
  filter(usgs_funny == 0)


ggplot() +
  geom_sf(data = subs_sf, fill = NA, col = "grey80", alpha = .3, lwd = .1) +
  geom_sf(data = reg_map_gages_sf, aes(fill = r_score), size = 3, shape = 21) +
  scale_fill_distiller(palette = "RdYlGn", 
                       limits = c(0, 1), 
                       direction = 1) +
  coord_sf(datum = NA) +
  theme_edf()



