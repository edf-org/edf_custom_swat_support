
## Purpose of script: 
## Extract gage height data from USGS API for gages in the study area
## (using USGS R package `dataRetrieval`)
## 
## Author: Greg Slater 
##
## Date Created: 2022-11-22
## ---------------------------

## load up packages
pacman::p_load(tidyverse, lubridate, paletteer, scales, dataRetrieval)

source("src/edf_theme.R")
source("src/functions.R")
theme_set(theme_edf())


# DATA IN -----------------------------------------------------------------

sub_gage_df <- read_csv("output/subbasin_gage_lookup.csv")

# Pull USGS data from API using package -----------------------------------

siteNo <- sub_gage_df$usgs_site_no
pCode <- "00065"
start.date <- "2005-01-01"
end.date <- "2014-12-31"

# pull data from USGS API
# usgs_extract <- readNWISdv(siteNumbers = siteNo,
#                            parameterCd = pCode,
#                            startDate = start.date,
#                            endDate = end.date)

# rename extract columns
usgs_extract <- renameNWISColumns(usgs_extract)
glimpse(usgs_extract)

# save
# write_csv(usgs_extract, "output/USGS/USGS_stage_data - daily - all gages.csv")