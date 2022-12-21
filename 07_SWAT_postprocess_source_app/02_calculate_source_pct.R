
## Purpose of script: 
## Create cross-tab of source to receptor subbasin chemical transfers
## and test basic maps
## 
## Author: Greg Slater 
##
## Date Created: 2022-12-20


## load up packages

pacman::p_load(tidyverse, lubridate, sf, janitor, viridis, RColorBrewer)

source("src/edf_theme.r")
source("src/functions.r")

# DATA IN -----------------------------------------------------------------

src.df <- read_csv("data/BQ/rch_source_app - chemtest.csv")
glimpse(src.df)

# read in subbasin sf and rivers sf
subs.sf <- st_read("data/spatial/subbasin/subs1_fixed.shp") %>%
  select(subbasin = Subbasin)

# rivers sf
rivs.sf <- st_read("data/spatial/riv1/riv1.shp") %>%
  select(subbasin = Subbasin)

# Analyse data ---------------------------------------------------------------

# group table by the receptor subbasin ID, and calculate the fraction of SOLPST_IN and SORPST_IN from each source subbasin.
receptor_pcts <- src.df %>% 
  group_by(receptor_sub) %>%
  mutate(solpst_pct = avg_solpst_in / sum(avg_solpst_in),
         sorpst_pct = avg_sorpst_in / sum(avg_sorpst_in)) %>% 
  arrange(receptor_sub)

# create a receptor sf table by joining to subbasin file
receptor_pcts.sf <- subs.sf %>% 
  inner_join(receptor_pcts, by = c("subbasin" = "source_sub")) %>% 
  arrange(receptor_sub)

# count how many source subbasins we have per receptor
# (this will be low for most as only 4 source subbasins in this data)
receptor_pcts %>% count(receptor_sub) %>% arrange(desc(n))


# Create map --------------------------------------------------------------

# list of receptor subbains
receptor_subs <- distinct(receptor_pcts, receptor_sub)

for (rec_sub in receptor_subs$receptor_sub){
  
  # create sf tables for receptor
  
  # sources
  src_subs.sf <- filter(receptor_pcts.sf, receptor_sub == rec_sub)
  # source and receptor labels
  src_subs_labs.sf <- subs.sf %>% 
    filter(subbasin %in% c(src_subs.sf$subbasin, rec_sub)) %>% 
    st_centroid()
  # receptor 
  rec_subs.sf <- filter(subs.sf, subbasin == rec_sub)
  
  # MAP
  
  m1 <- ggplot() +
    geom_sf(data = src_subs.sf,
            aes(fill = solpst_pct), 
            lwd = .3) +
    geom_sf(data = rec_subs.sf, 
            fill = NA, 
            aes(col = "receptor subbasin"), 
            lwd = 0.5) +
    
    scale_fill_distiller(palette = "YlGnBu", 
                         direction = 1, 
                         breaks = seq(0, 1, 0.2), 
                         limits = c(0, 1), 
                         labels = scales::percent) +  
    
    geom_sf_text(data = src_subs_labs.sf, 
                 aes(label = subbasin), 
                 col = "black",
                 size = 3, 
                 alpha = .5) +
    
    coord_sf(datum = NA) +
    theme_edf() +
    theme(legend.position = "right", 
          legend.text = element_text(size=7),
          legend.spacing.y = unit(0.1, "cm"),
          axis.title = element_blank()) +
    # guides(colour = guide_legend(ncol = 3, byrow = TRUE)) +
    labs(title = paste0("Soluble chemical source % for subbasin ", rec_sub), col = "")
  
  # save
  ggsave(paste0("figs/map - soluble chemical source pct by subbasin - receptor ", rec_sub, ".png"), 
         m1, units = "cm", height = 25, width = 20)
}

