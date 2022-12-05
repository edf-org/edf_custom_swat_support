
## Purpose of script: 
## Measure performance of SWAT models at predicting flood events by comparing
## bankfull % values with USGS gage height as a % of locatio minor flood stage height
## 
## Author: Greg Slater 
##
## Date Created: 2022-11-29
## ---------------------------

## load up packages

pacman::p_load(tidyverse, lubridate, paletteer, scales, dataRetrieval)

source("src/edf_theme.R")
source("src/functions.R")
theme_set(theme_edf())


# DATA IN -----------------------------------------------------------------

sub_gage_df <- read_csv("output/subbasin_gage_lookup.csv")


floods_swat_usgs_clean <- read_csv("output/floods_swat_usgs_clean_mod_thresh_0.85.csv", guess_max = 4000) %>% 
  inner_join(select(sub_gage_df, site_no, station_nm), by = "site_no") %>% 
  filter(usgs_funny == 0,
         !site_no %in% c("08068275", "08075900"))

nrow(floods_swat_usgs_clean)
count(floods_swat_usgs_clean, site_no)

# gages calibrated for flow
flow_gages <- read_csv("data/swat/SWAT model calibration dashboard_Summary Statistics_Table.csv")



# QUICK CHECKS ----------------------------------------------------


sub_eg <- filter(floods_swat_usgs_clean, 
                 model_info == "Original", 
                 subbasin == 221)

nrow(sub_eg)

ggplot(sub_eg, aes(swat_flood_pct, usgs_flood_pct)) +
  geom_point(size = 0.5, col = "steelblue3", alpha = 0.6)




# quick counts of flood days and events for USGS and SWAT
floods_swat_usgs_clean %>%
  filter(usgs_flood_ind == 1) %>%
  group_by(model_info) %>% 
  summarise(min = min(usgs_flood_pct),
            max = max(usgs_flood_pct),
            flood_events = n_distinct(paste0(site_no, usgs_event_id)),
            flood_days = sum(usgs_flood_ind)) #%>% copyExcel()


floods_swat_usgs_clean %>%
  filter(swat_flood_ind == 1) %>%
  group_by(model_info) %>% 
  summarise(min = min(swat_flood_pct),
            max = max(swat_flood_pct),
            flood_events = n_distinct(paste0(site_no, swat_event_id)),
            flood_days = sum(swat_flood_ind)) #%>% copyExcel()


# plotting distributions

dist_usgs <- floods_swat_usgs_clean %>%
  filter(model_info == "Original", usgs_funny == 0) %>% 
  ggplot(aes(usgs_flood_pct)) + 
  geom_histogram(fill = "steelblue", binwidth = 0.02) +
  geom_vline(xintercept = 1, col = "grey", linetype = "dashed") +
  labs(title = "Flood pct distribution - USGS")

ggsave("figs/flood_pct_distribution - USGS.png", dist_usgs, units = "cm", height = 7, width = 12)
  
dist_swat <- floods_swat_usgs_clean %>%
  # filter(model_info == "Original") %>% 
  ggplot(aes(swat_flood_pct, fill = model_info)) + 
  geom_histogram(binwidth = 0.02) +
  geom_vline(xintercept = 1, col = "grey", linetype = "dashed") +
  facet_wrap(model_info~., ncol = 1, scales = "free_x") +
  theme(legend.position = "none") +
  labs(title = "Flood pct distribution - SWAT")

ggsave("figs/flood_pct_distribution - swat.png", dist_swat, units = "cm", height = 18, width = 12)


# PRECISION AND RECALL per site -------------------------------------------

# calculate precision and recall for each subbasin and station
floods_usgs_swat_stats <- floods_swat_usgs_clean %>% 
  mutate(true_pos = ifelse(swat_flood_ind == 1 & usgs_flood_ind == 1, 1, 0)) %>%
  group_by(model_info, site_no, subbasin, station_nm, usgs_funny) %>%
  summarise(SWAT_flood_predictions = sum(swat_flood_ind),
            USGS_floods = sum(usgs_flood_ind),
            n_true_positives = sum(true_pos),
            precision = sum(true_pos) / sum(swat_flood_ind),
            recall = sum(true_pos) / sum(usgs_flood_ind),
            mean_flood_pct = mean(usgs_flood_pct), 
            mean_flood_pct_at_SWAT_predict = sum(usgs_flood_pct[swat_flood_ind == 1]) / sum(swat_flood_ind))

# write_csv(floods_usgs_swat_stats, "data/Floods - usgs and swat stats.csv")
floods_usgs_swat_stats

floods_swat_usgs_clean %>%
  count(model_info, usgs_flood_ind, swat_flood_ind)

floods_swat_usgs_clean %>% 
  filter(usgs_funny == 0) %>% 
  mutate(true_pos = ifelse(swat_flood_ind == 1 & usgs_flood_ind == 1, 1, 0)) %>%
  group_by(model_info) %>%
  summarise(SWAT_floods = sum(swat_flood_ind),
            USGS_floods = sum(usgs_flood_ind),
            n_true_positives = sum(true_pos),
            precision = sum(true_pos) / sum(swat_flood_ind),
            recall = sum(true_pos) / sum(usgs_flood_ind),
            mean_flood_pct = mean(usgs_flood_pct), 
            mean_flood_pct_at_SWAT_predict = sum(usgs_flood_pct[swat_flood_ind == 1]) / sum(swat_flood_ind)) %>% copyExcel()


# SITE SCORES AND RANKS ---------------------------------------------------

# count flood info for both USGS and SWAT - per site
usgs_counts <- floods_swat_usgs_clean %>%
  filter(usgs_flood_ind == 1,
         usgs_funny == 0,
         !site_no %in% c("08068275", "08075900")
         ) %>%
  group_by(model_info, site_no, usgs_event_id) %>%
  summarise(usgs_duration = n()) %>%
  group_by(model_info, site_no) %>%
  summarise(n_flood_events = n(), 
            n_flood_days = sum(usgs_duration),
            mean_duration = mean(usgs_duration)) %>% 
  pivot_longer(cols = c(n_flood_events, n_flood_days, mean_duration),
               names_to = "measure", values_to = "value") %>% 
  mutate(source = "usgs")


swat_counts <- floods_swat_usgs_clean %>%
  filter(swat_flood_ind == 1,
         usgs_funny == 0,
         !site_no %in% c("08068275", "08075900")
          ) %>%
  group_by(model_info, site_no, swat_event_id) %>%
  summarise(swat_duration = n()) %>%
  group_by(model_info, site_no) %>%
  summarise(n_flood_events = n(), 
            n_flood_days = sum(swat_duration),
            mean_duration = mean(swat_duration))  %>% 
  pivot_longer(cols = c(n_flood_events, n_flood_days, mean_duration),
               names_to = "measure", values_to = "value") %>% 
  mutate(source = "swat")



# join into table and add rank field
all_counts_nar <- bind_rows(usgs_counts, swat_counts) %>%
  group_by(model_info, source, measure) %>%
  mutate(rank = min_rank(value)) %>% arrange(source, measure)

# pivot out swat and usgs rank scores
all_ranks <- all_counts_nar %>% 
  ungroup() %>% 
  select(-value) %>% 
  pivot_wider(names_from = source, values_from = rank, values_fill = 0)

# pivot out swat and usgs measure scores
all_scores <- all_counts_nar %>% 
  ungroup() %>% 
  select(-rank) %>% 
  pivot_wider(names_from = source, values_from = value, values_fill = 0)


# COMPARE OVERALL FLOOD COUNTS USGS vs. SWAT PER MODEL
all_scores %>% group_by(model_info, measure) %>%
  filter(measure != "mean_duration") %>% 
  summarise(swat = sum(swat), 
            usgs = sum(usgs))


# create list of measures
# measures <- distinct(all_ranks, measure) %>% pull()
# names(measures) <- c("mean flood duration", "no. flood days", "no. flood events")

# all_scores %>% filter(measure == "n_flood_events") %>% view()


# RANK CHARTS - for each measure, compare the SWAT vs. USGS rank of gages across model runs

fig_rank_fld_ev <- ggplot(all_ranks %>% filter(measure == "n_flood_events"),
       aes(swat, usgs)) +
  geom_point() +
  geom_smooth(aes(swat, usgs), method="lm", se=FALSE) +
  facet_wrap(.~model_info, nrow = 1) +
  labs(title = "Site rank comparison: no. of flood events",
       subtitle = "SWAT predicted vs. USGS observed") +
  lims(y = c(0, 15), x = c(0, 15)) +
  theme(panel.background = element_rect(fill = "grey97", color = "white"),
        panel.spacing = unit(1, "cm"))

ggsave("figs/rank_metrics/n_flood_events.png", fig_rank_fld_ev, units = "cm", height = 8, width = 22)


fig_rank_dur <- ggplot(all_ranks %>% filter(measure == "mean_duration"),
       aes(swat, usgs)) +
  geom_point() +
  geom_smooth(aes(swat, usgs), method="lm", se=FALSE) +
  facet_wrap(.~model_info, scales = "free", nrow = 1) +
  labs(title = "Site rank comparison: average flood duration",
       subtitle = "SWAT predicted vs. USGS observed") +
  lims(y = c(0, 15), x = c(0, 15)) +
  theme(panel.background = element_rect(fill = "grey97", color = "white"),
        panel.spacing = unit(1, "cm"))

ggsave("figs/rank_metrics/mean_duration.png", fig_rank_dur, units = "cm", height = 8, width = 22)

fig_rank_fld_dy <- ggplot(all_ranks %>% filter(measure == "n_flood_days"),
       aes(swat, usgs)) +
  geom_point() +
  geom_smooth(aes(swat, usgs), method="lm", se=FALSE) +
  facet_wrap(.~model_info, scales = "free", nrow = 1) +
  labs(title = "Site rank comparison: total flood days",
       subtitle = "SWAT predicted vs. USGS observed") +
  lims(y = c(0, 15), x = c(0, 15)) +
  theme(panel.background = element_rect(fill = "grey97", color = "white"),
        panel.spacing = unit(1, "cm"))

ggsave("figs/rank_metrics/n_flood_days.png", fig_rank_fld_dy, units = "cm", height = 8, width = 22)


ggplot(all_scores,
       aes(swat, usgs)) +
  geom_point() +
  # facet_grid(measure~model_info, scales = "free", ) +
  facet_wrap(measure~model_info, scales = "free") +
  labs(title = "Site rank comparison",
       subtitle = "SWAT predicted vs. USGS observed ")




# EXAMINE MATCHING AND MIS-MATCHING SITES ---------------------------------

# take sample of sites per model for high and low SWAT & USGS rank scores crossover 
hi_lo_sample <- all_ranks %>%
  inner_join(flow_gages %>% select(site_no), by = "site_no") %>%
  filter(measure == "n_flood_events") %>% 
  group_by(model_info) %>% 
  mutate(swat_pctile = ntile(swat, 4),
         usgs_pctile = ntile(usgs, 4)) #%>% 
  # filter(swat_pctile %in% c(1, 4), usgs_pctile %in% c(1,4)) %>% 
  # group_by(model_info, swat_pctile, usgs_pctile) %>% 
  # sample_n(1)

#, swat_pctile = factor(swat_pctile, levels = c(1, 2), labels = c("Low", "High"))


# REGRESSION SCORING ------------------------------------------------------


sub_eg <- filter(floods_swat_usgs_clean, 
                 model_info == "Original", 
                 subbasin == 221)

sub_eg_score <- lm(swat_flood_pct~usgs_flood_pct, data = sub_eg)

summary(sub_eg_score)
summary(sub_eg_score)$r.squared

summary(sub_eg_score)


filter(floods_swat_usgs_clean, 
       model_info == "Run034_DepKellh",
       site_no == "08068090") %>% 
  
  ggplot(aes(swat_flood_pct, usgs_flood_pct)) +
  geom_point(col = "steelblue", size = 0.5, alpha = 0.5) +
  geom_smooth(aes(swat_flood_pct, usgs_flood_pct), method="lm", se=FALSE)


filter(floods_swat_usgs_clean, 
       model_info == "Run034_DepKellh",
       site_no == "08075900") %>% 
  
  ggplot(aes(swat_flood_pct, usgs_flood_pct)) +
  geom_point(col = "steelblue", size = 0.5, alpha = 0.5) +
  geom_smooth(aes(swat_flood_pct, usgs_flood_pct), method="lm", se=FALSE)


# SCORE ALL SITES & MODEL RUNS

model_runs <- distinct(floods_swat_usgs_clean, model_info) %>% pull()
sites <- distinct(floods_swat_usgs_clean, site_no) %>% pull()

reg_scores <- NULL

for(m in model_runs){
  for (s in sites){
    
    df <- filter(floods_swat_usgs_clean, 
                 model_info == m,
                 site_no == s)
    
    lm <- lm(swat_flood_pct~usgs_flood_pct, data = df)
    r_score <- summary(lm)$adj.r.squared

    df_out <- df %>%
      distinct(model_info, subbasin, site_no, station_nm, usgs_funny)

    df_out$r_score <- r_score

    reg_scores <- bind_rows(reg_scores, df_out)
  }
}

ggplot(reg_scores %>% filter(usgs_funny == 0), 
       aes(reorder(site_no, r_score), r_score, col = model_info)) +
  geom_point() +
  scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2)) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(title = "Flood % R squared values by gage", 
       x = "Gage") 
  # geom_bar(stat = "identity", position = "dodge2", width = 0.8)
  # facet_wrap(vars(model_info), ncol = 1)






# SCRAP

?facet_wrap

charts <- lapply(seq_along(measures), function(i){
  
  ggplot(all_ranks %>% filter(measure == measures[[i]]),
         aes(swat, usgs)) +
    geom_point()+
    labs(title = paste0("Site rank comparison: ", names(measures)[[i]]),
         subtitle = "SWAT predicted vs. USGS observed ")
})

scores <- lapply(seq_along(measures), function(i){
  
  lm(swat~usgs, data = filter(all_ranks, measure == measures[[i]]))
})

names(scores) <- unlist(measures)
summary(scores$mean_duration)$r.squared
summary(scores$mean_duration)


unlist(measures)

# Join together, using total list of site_nos as base
all_counts <- floods_swat_usgs_clean %>%
  distinct(site_no, usgs_funny) %>% 
  left_join(swat_counts, by = "site_no") %>% 
  left_join(usgs_counts, by = "site_no") %>% 
  replace(is.na(.), 0)
  
# rank each summary var and add into table
for (c in names(all_counts)[3:8]){
  all_counts[[paste0(c, "_r")]] <- min_rank(all_counts[[c]])
}

ggplot(all_counts, aes(swat_n_flood_events_r, 
                       usgs_n_flood_events_r, 
                       col = factor(usgs_funny))) + 
  geom_point() +
  scale_color_manual(values = c("steelblue3", "firebrick3"))

ggplot(all_counts, aes(swat_n_flood_events_r, 
                       usgs_n_flood_events_r, 
                       col = factor(usgs_funny))) + 
  geom_point() +
  scale_color_manual(values = c("steelblue3", "firebrick3"))


ggplot(all_counts, aes(swat_mean_duration_r, 
                       usgs_mean_duration_r, 
                       col = factor(usgs_funny))) + 
  geom_point() +
  scale_color_manual(values = c("steelblue3", "firebrick3"))


