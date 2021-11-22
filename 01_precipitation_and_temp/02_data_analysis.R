
pacman::p_load(tidyverse, lubridate, RColorBrewer, scales, sf)

source("src/edf_theme.R")
source("src/functions.R")
theme_set(theme_edf())


sink("output/log.txt")
paste0("run date: ", today())
sink()

# Load data ---------------------------------------------------------------

pattern <- "PCP.txt"

# list of all precip data files
file_names <- list.files(path="data/Deliverables/", pattern=pattern)

# read in all precip data files and bind into single dataframe
df_precip <- lapply(file_names, add_date_sub, cols = "precip") %>%
  bind_rows() %>%
  mutate(year = year(date),
         decade = year - year %% 10,
         decade_inc = ifelse(year(date) < 2020, year - year %% 10, 2010),
         decade_lab = factor(decade_inc, 
                             levels = seq(1980, 2010, 10),
                             labels = c("1980's", "1990's", "2000's", "2010 +")))


# write some basic checks to log file
sink("output/log.txt", append = TRUE, type = "output")
nrow(df_precip)
head(df_precip)
df_precip %>% count(decade_inc, decade_lab, decade)
sink()


# Precip data sanity checks -----------------------------------------------

# subset of data from just 20 subbasins, and set date var with constant year
precip_plot <- df_precip %>%
  filter(sub %in% distinct(df_precip, sub)$sub[1:5], year < 1986) %>%
  mutate(date_plot = update(date, year = 1980))

# plot using year as facet
year_facet <- ggplot(precip_plot, aes(date_plot, precip, col = factor(sub))) + 
    geom_line(lwd = .5) +
    facet_grid(year ~ .) +
    scale_x_date(date_labels="%b") +
    labs(title = "Precipitation by year and sub", col = "Sub", x = "Month")

year_facet
ggsave("figs/fig 1 - precip by year and sub.png", year_facet, units = "cm", width = 17, height = 20)

# plot using subbasin as facet
sub_facet <- ggplot(precip_plot, aes(date_plot, precip, col = factor(year))) + 
    geom_line(lwd = .5) +
    facet_grid(sub ~ .) +
    scale_x_date(date_labels="%b") +
    labs(title = "Precipitation by sub and year", col = "Year", x = "Month")

sub_facet
ggsave("figs/fig 2 - precip by sub and year.png", sub_facet, units = "cm", width = 17, height = 20)
         


# Map by subbasin ---------------------------------------------------------

# read in shapefile of subbasins
sf_sub <- read_sf("data/shp/subbasin/subs1.shp")
df_sub <- sf_sub %>% st_set_geometry(NULL)  

head(sf_sub)

# calculate decade means
decade_means <- df_precip %>% 
    group_by(sub, decade_inc, decade_lab) %>%
    summarise(precip_avg = mean(precip)) %>%
    group_by(sub) %>%
    mutate(avg_change = (precip_avg - first(precip_avg)) / first(precip_avg))


# calculate mean max annual precip
decade_avg_max <- df_precip %>% 
    group_by(sub, decade_inc, decade_lab, year) %>%
    summarise(min = min(precip),
              max = max(precip)) %>%
    group_by(sub, decade_inc, decade_lab) %>%
    summarise(precip_max_avg = mean(max)) %>%
    group_by(sub) %>%
    mutate(max_change = (precip_max_avg - first(precip_max_avg)) / first(precip_max_avg))

head(decade_avg_max)

# join decade calcs to sf
sf_sub_stats <- sf_sub %>%
    select(sub = OBJECTID) %>%
    inner_join(decade_means, by = "sub") %>%
    inner_join(select(decade_avg_max, -decade_lab), by = c("sub", "decade_inc"))

nrow(sf_sub_stats)
head(sf_sub_stats)

# plot - MEAN PRECIPITATION
m1_mean_precip <- ggplot() +
    geom_sf(data = sf_sub_stats, aes(fill = precip_avg), color = alpha("white", .2)) +
    coord_sf(datum = NA) +
    facet_grid(. ~ decade_lab) +
    scale_fill_gradientn(colours=(brewer.pal(8,"Blues"))) +
    theme(legend.position = "bottom") +
    labs(title = "Precipitation by decade", fill = "Mean precipitation")

ggsave("figs/m1 - mean precipitation by decade.png", m1_mean_precip, units = "cm", width = 20, height = 15)


# plot - CHANGE IN MEAN PRECIPITATION
m2_mean_precip_ch <- ggplot() +
    geom_sf(data = sf_sub_stats, aes(fill = avg_change), color = alpha("black", .1)) +
    coord_sf(datum = NA) +
    facet_grid(. ~ decade_lab) +
    # scale_fill_gradientn(colours=rev((brewer.pal(8,"PRGn"))), limits = c(-0.5, 0.5), labels = scales::percent) +
    scale_fill_gradient2(low = "#1b7837", mid = "white", high = "#762a83", midpoint = 0, labels = scales::percent) +
    theme(legend.position = "bottom") +
    labs(title = "Precipitation by decade", subtitle = "Change since 1980", fill = "% Change in precipitation from 1980")
    
ggsave("figs/m2 - mean precipitation by decade - change.png", m2_mean_precip_ch, units = "cm", width = 15, height = 10)


# plot - ANNUAL MAX PRECIPITATION
m3_max_precip <- ggplot() +
    geom_sf(data = sf_sub_stats, aes(fill = precip_max_avg), color = alpha("white", .2)) +
    coord_sf(datum = NA) +
    facet_grid(. ~ decade_lab) +
    scale_fill_gradientn(colours=(brewer.pal(8,"Blues"))) +
    theme(legend.position = "bottom") +
    labs(title = "Average annual max precipitation by decade", fill = "Decade-mean max annual precipitation")

ggsave("figs/m3 - max precipitation by decade.png", m3_max_precip, units = "cm", width = 20, height = 15)


# plot - CHANGE IN MEAN PRECIPITATION
m4_max_precip_ch <- ggplot() +
    geom_sf(data = sf_sub_stats, aes(fill = max_change), color = alpha("black", .1)) +
    coord_sf(datum = NA) +
    facet_grid(. ~ decade_lab) +
    # scale_fill_gradientn(colours=rev((brewer.pal(8,"PRGn"))), labels = scales::percent, limits = c(-1.5, 1.5)) +
    scale_fill_gradient2(low = "#1b7837", mid = "white", high = "#762a83", midpoint = 0, labels = scales::percent) +
    theme(legend.position = "bottom") +
    labs(title = "Average annual max precipitation by decade", subtitle = "Change since 1980", 
         fill = "% change in Decade-mean max\nannual precitiation from 1980")  

ggsave("figs/m4 - max precipitation by decade - change.png", m4_max_precip_ch, units = "cm", width = 15, height = 10)
