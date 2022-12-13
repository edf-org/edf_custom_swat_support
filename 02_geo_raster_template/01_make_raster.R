

## Purpose of script: 
## To create a raster file at 100-100m resolution that covers the study area
## and save a csv of the cell ids and reference to act as a lookup
## 
## Author: Greg Slater 
##
## Date Created: 2022-12-13
## ---------------------------

## load up packages
pacman::p_load(tidyverse, lubridate, viridis, RColorBrewer, scales, stars, sf)

source("src/edf_theme.r")
theme_set(theme_edf())


# Load data ---------------------------------------------------------------

# bounding box of watershed and subbasins combined - this is the study area extent  
study_area <- st_read("data/watershed_subbasin_bbox/watershed_subbasin_bbox.shp")


# Create raster ---------------------------------------------------------------

# create 100x100m grid of the study area using the bounding box
sa_grid <- study_area %>%
  st_bbox() %>%
  st_as_stars(dx = 100, dy = 100)

# grid dimensions
x_dim <- dim(sa_grid[[1]])['x']
y_dim <- dim(sa_grid[[1]])['y']

# create a matrix to replace the empty values in the grid raster, with sequential numbers
# in stars, the matrix columns become north - south rows of data (i.e. origin is top left)
# so nrow must be x dimension of wp data, and xcol y dimension

sa_mat <- matrix(seq(1, (x_dim * y_dim), 1),
                 nrow = x_dim,
                 ncol = y_dim)

# create template with sequential matrix replacing empty values
template <- sa_grid
template[[1]] <- sa_mat

# check values in raster values array are as expected
# min value is the first value
min(template[[1]]) == template[[1]][1]
# max value is the last and == x*y dimensions
max(template[[1]]) == template[[1]][x_dim*y_dim]

# save template
template %>% write_stars("output/raster_template/raster_template.tif")



# Export as csv -----------------------------------------------------------

m_out <- template[[1]]

# give matrix dimension x, y names and range of values from 1 to x, y extents 
dimnames(m_out) <- list(x = seq(1, dim(sa_grid[[1]])['x'], 1), 
                        y = seq(1, dim(sa_grid[[1]])['y'], 1))


# turn into table, change col names
df <- as.data.frame(as.table(m_out))
names(df) <- c('x', 'y', 'cell_id')
head(df)

# save csv
df %>% write_csv("output/raster_template/raster_template.csv")
