
# function to print text and a ruler in output - useful for highlighting key points
rule <- function(..., pad = "-") {
  title <- paste0(...)
  width <- getOption("width") - nchar(title) - 5
  cat(title, " ", stringr::str_dup(pad, width), "\n", sep = "")
}



#  DATASET PROCESSING FUNCTIONS

# create raster from shapefile vectors
sf_to_raster <- function(shapefile, col_name, raster_template){
    
    # get callable version of col name
    var <- enquo(col_name)
    
    # set raster template vals to NA
    raster_template[[1]][] <- NA
    
    # select only target column
    sf <- shapefile %>%
        select(!!var)
    
#   rasterise
    sf %>%
        st_rasterize(template = raster_template)
}

# create df from raster
raster_to_df <- function(raster){
    
    # create new df with same n rows as raster cells
    df <- data.frame("cell_id" = seq(1, length(raster[[1]]), 1),
                     "value" = NA)

    # set df values to raster cell values
    df$value <- raster[[1]][df$cell_id]
    
    df
}


## Create raster from csv
csv_to_raster <- function(df, cell_id, var_name, raster_template){
    
    # set all raster values to NA
    raster_template[[1]][] <- NA
    
    # set raster cells present in input df to values from input df
    raster_template[[1]][df[[cell_id]]] <- df[[var_name]]
    
    raster_template
}
