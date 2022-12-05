
## Purpose of script: 
## Join extracted USGS gage height data and join to SWAT bankfull % data
## in a single table.
## 
## Author: Greg Slater 
##
## Date Created: 2022-11-29
## ---------------------------

## load up packages
pacman::p_load(tidyverse, lubridate, paletteer, scales)

source("src/edf_theme.R")
source("src/functions.R")
theme_set(theme_edf())


# DATA IN -----------------------------------------------------------------

usgs_extract <- read_csv("output/USGS/USGS_stage_data - daily - all gages.csv", 
                         guess_max = 35000) %>%
  filter(!is.na(GH))

nrow(usgs_extract)
head(usgs_extract)

# calculated from USGS site - flood classification heights for some gage sites
f_heights <- read_csv("data/USGS/usgs gages - flood heights.csv") %>%
  filter(!is.na(minor_flood_stage_ft)) %>%
  select(site_no, minor_flood_stage_ft) %>%
  mutate(site_no = paste0("0", site_no))

# subbasin - gage lookup
sub_gage_df <- read_csv("output/subbasin_gage_lookup.csv")

# daily swat flood estimates - this is for a number of model runs

model_runs <- c("Original", "Run032_DepHeyTho", "Run033_DepWillms", "Run034_DepKellh")

# bind list of read in csvs, tweaking variable names and adding in model_info field
sub_bfull_daily <- bind_rows(
  lapply(
    model_runs,
    function(x){
      paste0("data/swat/BQ_bankfull_pct_", x, ".csv") %>% 
      read_csv() %>%
        rename(date = datestamp,
               subbasin = Subbasin,
               swat_flood_pct = bankfullpct,
               swat_flood_ind = isabovebankfull,
               swat_event_id = eventid) %>%
        mutate(model_info = x,
               swat_event_id = ifelse(swat_flood_ind == 0, NA, swat_event_id)) %>%
        select(-isstartevent)
    }))

head(sub_bfull_daily)
count(sub_bfull_daily, model_info)



# SWAT FLOOD DATA ---------------------------------------------------------

# SENSE CHECKS
# take a look at the average daily flood % to check different distributions per model
sub_bfull_daily %>% group_by(model_info, date) %>% 
  summarise(flood_pct = mean(log(swat_flood_pct))) %>% 
  ggplot(aes(x = model_info, y = flood_pct)) +
    geom_boxplot()


# summarise bankfull data to flooding days only
sub_bfull_floods <- sub_bfull_daily %>%
  filter(swat_flood_ind == 1) %>% 
  arrange(subbasin, date) %>%
  group_by(subbasin, swat_event_id) %>%
  summarise(flood_start_date = min(date),
            bfull_duration_days = n())

# summarise bankfull data to n floods per subbasin
sub_bfull_summary <- sub_bfull_floods %>%
  group_by(subbasin) %>%
  summarise(total_bfull_days = sum(bfull_duration_days),
            mean_bfull_days = mean(bfull_duration_days))



# USGS FLOOD DATA ----------------------------------------------------

## FUNNY USGS DATA
# A few sites have sudden step changes in gage heights. Flagging these to identify impact on model results

usgs_funnies <- c("08067500", "08068000", "08068720", "08068800", "08069000", "08072730", "08072760")


# set threshold of minor flood stage at which to flag stage height as a flood
# e.g. 0.75 will mean all days with gage height >= 75% of minor flood stage will be flagged
flood_thresh <- 0.85

# note - creating a flood indicator to be >= 75% of minor flood stage
USGS_floods_base <- usgs_extract %>%
  select(site_no, date = Date, GH) %>%
  inner_join(f_heights, by = "site_no") %>%
  mutate(
    usgs_flood_pct = GH / minor_flood_stage_ft,
    usgs_flood_ind = ifelse(GH >= (minor_flood_stage_ft * flood_thresh), 1, 0),
    usgs_funny = ifelse(site_no %in% usgs_funnies, 1, 0)
  )

# USGS_flood_type = case_when((GH >= (minor_flood_stage_ft * .75)) &
#                               (GH < minor_flood_stage_ft) ~ "Close to flood (>= 75%)",
#                             GH >= minor_flood_stage_ft ~ "MINOR FLOOD",
#                             TRUE ~ ""))

# create event_id field for USGS floods

# table of only flood days, sorted by site and date
# event id = 1 by default
USGS_floods_only <- USGS_floods_base %>% 
  filter(usgs_flood_ind == 1) %>%
  mutate(usgs_event_id = 1)

# loop through and increment each time date jumps by more than 1, start from 1 again if site changes
for (r in 2:nrow(USGS_floods_only)){
  
  # if the next row is a new site, skip, this event_id = 1 as it's the first
  if (USGS_floods_only$site_no[r] != USGS_floods_only$site_no[r - 1]){
    next
  }
  # if the current row date is more than a day after the last one, increment event_id
  if (as.numeric(USGS_floods_only$date[r] - USGS_floods_only$date[r - 1]) != 1){
    USGS_floods_only$usgs_event_id[r] = USGS_floods_only$usgs_event_id[r -1] + 1
  } else {
    # else keep it the same
    USGS_floods_only$usgs_event_id[r] = USGS_floods_only$usgs_event_id[r -1]
  }
}

# join back on to main flood table
USGS_floods <- USGS_floods_base %>%
  left_join(USGS_floods_only %>% select(site_no, date, usgs_event_id),
            by = c("site_no", "date"))




# check event ID grouping
USGS_floods %>% group_by(site_no, usgs_event_id) %>%
  summarise(days = n(), 
            min = min(date),
            max = max(date)) %>% 
  filter(!is.na(usgs_event_id))

# table of sites we have data for
USGS_sites <- USGS_floods %>% distinct(site_no)

USGS_floods %>% 
  # filter(usgs_flood_pct > 0.75)
  filter(usgs_flood_ind == 1)



# JOIN SWAT AND USGS DATA -------------------------------------------------

# start with full swat range, join to sub>gage lookup to limit to 
# just subbasins with gages, then join to USGS data sites to limit
# to just sites we have data for

swat_sub_sites_daily <- sub_bfull_daily %>%
  inner_join(sub_gage_df %>% select(subbasin, site_no),
             by = "subbasin") %>%
  inner_join(USGS_sites, by = "site_no")

nrow(swat_sub_sites_daily)

# left join all USGS data and flag when it's present
floods_swat_usgs <- swat_sub_sites_daily %>%
  left_join(USGS_floods, by = c("site_no", "date")) %>%
  mutate(usgs_data = ifelse(is.na(GH), 0, 1))

# how many days with either USGS or SWAT floods ocurring
floods_swat_usgs %>% 
  filter(usgs_flood_ind == 1 | swat_flood_ind == 1) %>% 
  nrow()

# check the join to USGS data hasn't introduced dupes
# nrow(total SWAT days for subbasins and sites) == joined table
swat_sub_sites_daily %>% nrow()
floods_swat_usgs %>% nrow()
floods_swat_usgs %>% count(model_info)

# check if any sites have significant gaps of USGS data - these should be excluded from analysis
overlap_check <- floods_swat_usgs %>% 
  group_by(model_info, subbasin, site_no) %>%
  summarise(swat_days = n(),
            usgs_days = sum(usgs_data),
            usgs_data_overlap = sum(usgs_data) / n()) %>% 
  filter(usgs_days > 1) %>%
  arrange(usgs_data_overlap)

# total subbasins with some USGS data:
nrow(USGS_sites)
# subbasins with good overlap of USGS data:
nrow(overlap_check %>% filter(usgs_data_overlap > 0.95) %>% ungroup() %>% distinct(site_no))





# restrict output table to just good overlap sites
# also get rid of missing USGS data days, and replace event_id NAs with 0
floods_swat_usgs_clean <- floods_swat_usgs %>%
  inner_join(overlap_check %>% filter(usgs_data_overlap > 0.95),
             by = c("model_info", "subbasin", "site_no")) %>%
  select(-c(swat_days, usgs_days)) %>%
  filter(!is.na(GH)) %>%
  replace(is.na(.), 0)

nrow(floods_swat_usgs)
nrow(floods_swat_usgs_clean)

floods_swat_usgs %>% count(model_info)
floods_swat_usgs_clean %>% count(model_info)

# save comparison table
floods_swat_usgs_clean %>% 
  write_csv(paste0("output/floods_swat_usgs_clean_mod_thresh_", flood_thresh,  ".csv"))



floods_swat_usgs_clean %>%
  filter(usgs_flood_ind == 1) %>%
  group_by(model_info) %>% 
  summarise(min = min(usgs_flood_pct),
            max = max(usgs_flood_pct),
            flood_days = sum(usgs_flood_ind),
            flood_events = n_distinct(paste0(site_no, usgs_event_id)))


