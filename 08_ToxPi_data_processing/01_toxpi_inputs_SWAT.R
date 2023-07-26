## Purpose of script: 
## Transform the gpkg SWAT outputs into raster and save as csv
## 
## Author: Greg Slater 
## Modified by: Alex Adame
## Date Created: 2022-10-26 Updated: 2023-05-31


## load up packages

pacman::p_load(tidyverse, lubridate, stars, sf) 

source("src/edf_theme.r")
source("src/functions.r")

# DATA IN -----------------------------------------------------------------

# raster template
rt <- read_stars("data/raster_template/raster_template.tif")

# SWAT data (gpkg to save full colnames)
swat_data <- st_read("data/ToxPi_inputs/SWAT/subbasins_chem_20050101_20201231.gpkg", "subbasins_chem_data")

# PROCESSING --------------------------------------------------------------
# select all data matching 'chemconc' in col name
swat_chem_cols <- swat_data %>% select(all_of(matches('chemconc')))

# rasterize and export each variable to a tif file
swat_chem.rt <- list()

for (i in colnames(swat_chem_cols)){
    swat_chem.rt[[i]] <- sf_to_raster(swat_data, i, rt)
    filename = paste("output/ToxPi_inputs_processed/SWAT/",i,".tif", sep = "")
    write_stars(swat_chem.rt[[i]], filename)
}

# create df from raster with all variables
templist = list()

for (i in names(swat_chem.rt)){
    output = raster_to_df(swat_chem.rt[[i]])
    templist[["cell_id"]] = output$cell_id
    templist[[i]] = output$value
}
swat_chem.df = data.frame(templist)
swat_chem.df <- subset(swat_chem.df, select = -c(geom)) #drop geom col

# write df to csv
write_csv(swat_chem.df %>% drop_na(), "output/ToxPi_inputs_processed/SWAT/chem_conc.csv")
