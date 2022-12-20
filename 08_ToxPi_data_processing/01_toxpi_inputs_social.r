
# NOTE - this is just a straight extract of the original .ipynb file
# there is also an .html version which will be a bit easier to view

pacman::p_load(tidyverse, lubridate, stars, sf)

source("src/edf_theme.r")
source("src/functions.r")
theme_set(theme_edf())

options(repr.plot.width=8, repr.plot.height=3)
options(scipen=999)  # turn off scientific numbers

# census tracts clipped to the study area
sf_tracts <- st_read("data/study_area_census_tracts_clipped/study_area_census_tracts_clipped.shp") %>%
    rename(geoid = FIPS) %>%
    mutate(geoid = as.character(geoid))

df_tracts <- sf_tracts %>% st_set_geometry(NULL)
# df_tracts <- read_csv("data/study_area_census_tracts/study_area_census_tracts.csv") %>%
#     rename(geoid = FIPS) %>%
#     mutate(geoid = as.character(geoid))


# table of all the raster cells which are covered by census tracts - used to limit wide output table for smaller size
df_study_clipped <- read_csv("data/raster_template/raster_template_study_area_lookup.csv") %>%
    filter(study_area == 1)

nrow(sf_tracts)
head(sf_tracts)

rt <- read_stars("data/raster_template/raster_template.tif")

# lookup file for datasets to be processed
file_key <- read_csv("data/CVI for Gulf_2 - csv 2022_07_04.csv")

nrow(file_key)
head(file_key)

nrow(df_tracts)

df_study_clipped %>% count(study_area)

plot(sf_tracts[, 1])

targ <- file_key %>%
#     filter(to_process == 1 & processed != 1) %>%
    filter(`Document Name` %in% c("PercentHousing1940-1969", "Native Lands_63022"))  %>% 
    distinct(`Path To File`, `GEOID Column Name`) %>% 
    as.data.frame()

targ

for (i in 1:nrow(targ)) {
# for (i in 1:1) {

    # take file path and geoid column name from file key
    path <- paste0("data/ToxPi_inputs/", targ[i, "Path To File"])
    geoid_col_name <- targ[i, "GEOID Column Name"]
    
    # read in file and create new character geoid field
    df <- read_csv(path) %>%
        mutate(geoid = as.character(!!as.symbol(geoid_col_name)))
    
    # get list of all required data fields in file from file_key
    fields <- filter(file_key, `Path To File` == targ[i, "Path To File"]) %>%
    distinct(`Data Column Name`) %>% 
    pull()
    
    # filter to study area tracts, select required columns, and save
    df %>%
        filter(geoid %in% df_tracts$geoid) %>%
        select(geoid, all_of(fields)) %>%
        write_csv(str_replace(path, ".csv", " - study_area.csv"))

}

# this is just to create a wide dataset from the narrow table the data is provided in
health_fields <- c("CASTHMA", "STROKE", "COPD", "CHD", "CANCER", "ACCESS2")

df_health_wide <- read_csv("data/Health/PLACES__Local_Data_for_Better_Health__Census_Tract_Data_2021_release.csv") %>%
    rename(geoid = LocationName) %>%
    filter(geoid %in% df_tracts$geoid, MeasureId %in% health_fields) %>%
    select(geoid, Data_Value, MeasureId)

nrow(df_health_wide)
head(df_health_wide)

df_health_wide %>% 
    spread(value = Data_Value, key = MeasureId) %>%
    head() 
#     write_csv("data/Health/PLACES__Local_Data_for_Better_Health__Census_Tract_Data_2021_release - study_area.csv")

# recode categorical variable
df <- read_csv("data/ToxPi_inputs/Health/MedicallyUnderserved - study_area.csv") %>% 
    rename(label = `Medically Underserved Areas (MUA), as of 2020.`) %>%
    mutate(value = case_when(label == "Not an MUA or MUP" ~ 1, 
                             label %in% c("Medically Underserved Population", 
                                          "Medically Underserved Population - Governor's Exception") ~ 2,
                             label == "Medically Underserved Area" ~ 3,
                             TRUE ~ 0)) %>%
    rename(`Medically Underserved Areas (MUA), as of 2020.` = value)

df %>% count(`Medically Underserved Areas (MUA), as of 2020.`, label)

df

df %>% select(-label) %>% write_csv("data/ToxPi_inputs/Health/MedicallyUnderserved - coded - study_area.csv")

count(df, `Medically Underserved Areas (MUA), as of 2020.`)

rl <- st_read("data/ToxPi_inputs/Infrastructure/redlining/redlining_A-E_districts_study_area.gpkg") %>%
    st_transform(6587) %>%
    mutate(value = case_when(holc_grade == "A" ~ 1,
                             holc_grade == "B" ~ 2,
                             holc_grade == "C" ~ 3,
                             holc_grade == "D" ~ 4))

nrow(rl)
head(rl)

rl %>% st_set_geometry(NULL) %>% count(holc_grade, value)

plot(rl[, "holc_grade"])

head(rl)

# rasterise polygon data and write to tif to check in QGIS

# copy raster template, set all cells to NA, then all study area cells to 0
# this should ensure study area is 0 or 1 based on RL areas, beyond study area will be NA
rl_rast_blank <- rt
rl_rast_blank[[1]][] <- NA
rl_rast_blank[[1]][df_study_clipped$cell_id] <- 0


rl_rast <- rl %>% 
    select(value) %>%
    st_rasterize(template = rl_rast_blank, options = "ALL_TOUCHED=TRUE")

rl_rast

write_stars(rl_rast, "data/ToxPi_inputs/Infrastructure/redlining/redlining_A-E_districts_study_area.tif")

# transform to df and write to csv file
rl_output <- raster_to_df(rl_rast)

nrow(rl_output)
rl_output %>% drop_na() %>% nrow()
head(rl_output)

rl_output %>% drop_na() %>% write_csv("outputs/ToxPi_inputs_processed/Infrastructure_Redlining1.csv")

rl_output %>% count(value)



zip_sf <- st_read("data/zip_codes_study_area/Zip codes study area.gpkg") %>%
    st_transform(6587)

nfip_df <- read_csv("data/ToxPi_inputs/Social/FEMA_NFIP_market_penetration.csv") %>%
    select(AFFGEOID10, market_pen = `Market Penetration`)

nrow(zip_sf)
nrow(nfip_df)

# inner join zip code sf to data
# and clip to study area extent

tracts_boundary_sf <- sf_tracts %>% st_union()

nfip_sf <- zip_sf %>% 
    select(AFFGEOID10) %>%
    inner_join(nfip_df, by = "AFFGEOID10") %>% 
    st_intersection(tracts_boundary_sf)

plot(nfip_sf["market_pen"])

new_rast <- rt
new_rast[[1]][] <- NA

# rasterise sf file and export to .tif
nfip_rt <- nfip_sf %>% 
    select(value = market_pen) %>%
    st_rasterize(template = new_rast)

nfip_rt %>% write_stars("outputs/ToxPi_inputs_processed/Social_FloodInsPenetration.tif")

# write NFIP raster to csv
raster_to_df(nfip_rt) %>% 
    drop_na() %>%
    write_csv("outputs/ToxPi_inputs_processed/Social_FloodInsPenetration.csv")

head(zip_sf)

head(nfip_df)





targ2 <- file_key %>%
    filter(to_process == 1) %>%
#     filter(`Document Name` == "MedicallyUnderserved") %>%
    as.data.frame()

targ2
# targ2[17:18, ]



# set raster template values to NA
rt[[1]][] <- NA

# create logging df
log_df <- data.frame()

# df for wide output of all raster data - these are just all raster cells covered by census tracts, not full raster area
wide_output_df <- data.frame("cell_id" = df_study_clipped$cell_id)


# loop through data sets in the target list

for (i in 1:nrow(targ2)) {
# for (i in 1:2) {

    # take file path from file key
    path_data <- paste0("data/ToxPi_inputs/", targ2[i, "Path To File"]) %>%
        str_replace(".csv", " - study_area.csv")
    
    # __ FIELDS AND FILE PATHS __________________________________________ # 
    
    # create nice short name for indicator by combining domain and short indicator
    dom <- targ2[i, "Domain"]
    ind <- targ2[i, "indicator_name_short"]
    
    ind_name <- paste(dom, ind, sep = "_")
    
    # pull important fields from data_key
    data_field <- targ2[i, "Data Column Name"]
#     missing_field <- as.numeric(targ2[i, "missing_data_value"])
    
    # new folder path to save file-specific outputs
#     path_out <- file.path(getwd(), "data/09_processed", ind_name)
#     dir.create(path_out)
    
    
    # __ LOGGING AND FILE READ-IN __________________________________________ # 
    
#     sink(file.path(path_out, "log.txt"))
    print("---------------------------------------------------------")
    print("FILE READ")
    print(paste0("Processing file: ", path_data))
    print(paste0("Processing date: ", now()))
    

    # read in file (with field type default as numeric, geoid as character), 
    # rename data field as value, and restrict to tracts in sf
    df <- read_csv(path_data, col_types = cols(.default = "n", geoid = "c")) %>%
        rename(value = !!as.symbol(data_field)) %>%
        select(geoid, value) %>%
        filter(geoid %in% sf_tracts$geoid)
    
    # array of all non missing values
    non_missing_vals <- df %>%
        filter(!is.na(value) & value != -999) %>%
        pull(value) 
    
    # count missing values
    n_missing_vals <- df %>%
        filter(is.na(value) | value == -999) %>%
        nrow()
    
    # set value to 0 before if clause
    missing_tracts <- data.frame()
    
    # __ MISSING VALUES AND TRACTS __________________________________________ # 
    
    # if there are missing census tracts or missing values
    if ((nrow(df) < nrow(sf_tracts)) | (n_missing_vals > 0)){
        
        # if tracts in the input data have NA or -999 values
        if (n_missing_vals > 0){

            # replace missing values (NA or -999) with -999
            df <- df %>%
                mutate(value = ifelse(is.na(value) | value == -999, 
                                      -999,
                                      value))

            print("MISSING DATA")
            print(paste0(n_missing_vals, " missing values found in file"))
#             print(paste0("replacing with study area median: ", median(non_missing_vals)))
            
        }
        
        # if there are fewer census tracts in the input data (df) than the study area
        if (nrow(df) < nrow(sf_tracts)){
        
            # geoids of missing tracts
            missing_tracts <- df_tracts %>%
                select(geoid) %>%
                filter(!geoid %in% df$geoid) #%>%
    #             mutate(value = median(non_missing_vals))

            # give missing geoids median value and join to orig data
            df <- df %>%
                full_join(missing_tracts, by = "geoid") #%>%
    #             mutate(value = ifelse(is.na(value.x), value.y, value.x))

            print("MISSING TRACTS")
            print(paste0(nrow(missing_tracts), " tracts are missing from input file"))
#             print(paste0("replacing with study area median: ", median(non_missing_vals)))
            
        }
        
    } 
    
#     # __DATA OVERVIEWS__________________________________________ # 
    
#     pl_hist <- ggplot(df, aes(value)) + geom_histogram() +
#         labs(title = paste0("Distribution: ", ind_name),
#              x = data_field) +
#         scale_fill_edf("health")
    
#     pl_box <- ggplot(df, aes(value)) + geom_boxplot(width = .5, alpha = .8) +
#         labs(title = paste0("Distribution: ", ind_name),
#              x = data_field) +
#         theme(axis.text.y = element_blank())
    
#     ggsave(file.path(path_out, paste0("fig histogram - ", ind_name, ".png")),
#            pl_hist,
#            units = "cm", width = 15, height = 6)
    
#     ggsave(file.path(path_out, paste0("fig boxplot - ", ind_name, ".png")),
#            pl_box,
#            units = "cm", width = 12, height = 4)
    
    
    # __ RASTERISATION __________________________________________ #
    
    # create sf file for new data by joining to tracts sf, and keep only data value
    sf_new_data <- sf_tracts %>% 
        inner_join(df, by = "geoid") %>%
        select(value)
    
    print("GEOGRAPHY FUNCTIONS")
    print(paste0("No. of census tracts in study area: ", nrow(sf_tracts)))
    print(paste0("No. of joined census tracts joined to ", ind_name, " data: ", nrow(sf_new_data)))
    
    # create raster dataset
    r_new_data <- sf_new_data %>%
        st_rasterize(template = rt)
    
    # create data frame output for dataset
    df_new_data <- data.frame("cell_id" = seq(1, length(r_new_data[[1]]), 1),
                              "value" = NA)

    df_new_data$value <- r_new_data[[1]][df_new_data$cell_id]
    
#     write_stars(r_new_data, file.path(path_out, paste0(ind_name, ".tif")))
#     write_csv(df_new_data %>% drop_na(), file.path(path_out, paste0(ind_name, ".csv")))
    
    print("OUTPUTS")
    print(paste0("Created file: ", paste0(ind_name, ".tif")))
    print(paste0("n records: ", format(length(r_new_data[[1]]), big.mark=",")))
    print(paste0("Created file: ", paste0(ind_name, ".csv")))
    print(paste0("n records (with NAs removed): ", format(nrow(df_new_data %>% drop_na()), big.mark=",")))
    
#     append data to wide table
    wide_output_df[ind_name] <- r_new_data[[1]][wide_output_df$cell_id]
    
#     # __ QUICK MAP __________________________________________ #
    
#     pl_map <- ggplot() +  
#         geom_raster(data = as.data.frame(r_new_data), aes(x = x, y = y, fill = value)) +
#         scale_fill_viridis(na.value = "white") +
#         coord_sf(datum = NA) +
#         labs(title = paste0("Rasterised data in study area: ", ind_name)) +
#         theme(plot.title = element_text(size = 8))
    
#     ggsave(file.path(path_out, paste0("fig raster map - ", ind_name, ".png")),
#            pl_map,
#            units = "cm", width = 10, height = 10)


    
    # __ LOG DF __________________________________________ #
    log <- data.frame("file" = as.character(ind_name),
                      "n_missing_values" = n_missing_vals,
                      "n_missing_tracts" = nrow(missing_tracts),
                      "study_area_min" = min(non_missing_vals),
                      "study_area_median" = median(non_missing_vals),
                      "study_area_max" = max(non_missing_vals),
                      stringsAsFactors = F)
    
    log_df <- bind_rows(log_df, log)

#     print("---------------------------------------------------------")
}


# save log & wide df
fn_log <- paste0("ToxPi_DataProcessingLog_", format(now(), "%Y%m%d_%H%M"), ".csv")
write_csv(log_df, paste0("outputs/ToxPi_inputs_processed/", fn_log))

# fn_output <- paste0("ToxPiDataInput_v2.0_", format(now(), "%Y%m%d"), ".csv")
# write_csv(wide_output_df, paste0("outputs/ToxPi_inputs_processed/", fn_output))

fn_output <- paste0("ToxPi_DataInput_v2.1_", format(now(), "%Y%m%d"), ".csv")
write_csv(wide_output_df, paste0("outputs/ToxPi_inputs_processed/", fn_output))

# paste0("outputs/ToxPi_inputs_processed/", fn_output)

head(wide_output_df)











nrow(df_new_data)
nrow(df_new_data %>% drop_na())

write_csv(df_new_data %>% drop_na(), file.path(path_out, paste0(ind_name, "_clipped.csv")))

write_stars(r_new_data, file.path(path_out, paste0(ind_name, ".tif")))

file.path(path_out, paste0(ind_name, ".tif"))

df_study_clipped <- df_new_data %>% 
    mutate(study_area = ifelse(is.na(value), 0, 1)) %>%
    select(cell_id, study_area)

# write_csv(df_study_clipped, "data/raster_template/raster_template_study_area_lookup.csv")

nrow(df_study_clipped)
head(df_study_clipped)

rt_study_area <- rt

rt_study_area[[1]][] <- NA

# set raster cells present in input df to values from input df
rt_study_area[[1]][df_study_clipped$cell_id] <- df_study_clipped$study_area

# write output tif
write_stars(rt_study_area, "data/raster_template/raster_template_study_area_lookup.tif")

nrow(wide_output_df)


# write_csv(wide_output_df, paste0("outputs/ToxPi_inputs_processed/", fn_output))

paste0("outputs/ToxPi_inputs_processed/", fn_output)

# join red lining data to wide output file and save output

fn_output <- paste0("ToxPi_DataInput_v2.1_", format(now(), "%Y%m%d"), ".csv")

wide_output_df %>% 
    left_join(select(rl_output, cell_id, Infrastructure_Redlining1 = value), 
              by = "cell_id") %>% 
#     head()
    write_csv(paste0("outputs/ToxPi_inputs_processed/", fn_output))

nrow(wide_output_df)



targ3 <- file_key %>%
    filter(processed == 1) %>%
    as.data.frame()

targ3


df_wide <- read_csv("data/processed/Health_LifeExpectancy/Health_LifeExpectancy.csv") %>%
    select(cell_id)

# df_wide
for (i in 1:nrow(targ3)) {
# for (i in 1:2) {

    
    # create nice short name for indicator by combining domain and short indicator
    dom <- targ3[i, "Domain"]
    ind <- targ3[i, "indicator_name_short"]
    
    ind_name <- paste(dom, ind, sep = "_")
    
    # read in the processed dataset using the ind_name for folder and filenames
    path_df <- file.path(getwd(), paste0("data/processed/", ind_name, "/", ind_name, ".csv"))
    print(path_df)
    
    df <- read_csv(path_df)
    
    # add the processed value to df_wide named with the ind_name
    df_wide[ind_name] <- df["value"]
    
    }

head(df_wide)

# count the no. of NAs per row, this is to make sure that the 
# drop_na below isn't getting rid of rows where just one column is missing data
df_wide$na_count <- apply(is.na(df_wide), 1, sum)

count(df_wide, na_count)

# get rid of rows with NA values and save file
df_wide %>% 
    drop_na() %>%
    write_csv("data/processed/ToxPi_data_input_wide.csv")

# create a csv template of just cell_ids with 
df_wide %>% 
    drop_na() %>%
    write_csv("data/processed/ToxPi_data_input_wide.csv")





?drop_na()

df <- tibble(x = c(1, 2, NA), y = c("a", NA, "b"))
df %>% drop_na()
df %>% drop_na(x)
