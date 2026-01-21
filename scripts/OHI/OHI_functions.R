## These are functions pulled from https://github.com/OHI-Science/ohi-global/blob/draft/eez/conf/functions.R and customized to run in BON in a Box.
library(tidyverse)
input <- biab_inputs()

# scen_year <- layers$data$scenario_year

# Loading the layers (this will be a csv array with the habitat and the value, don't neeed region ID because it is only for your region of interest)


# get data together: read in csvs and rbind
hab_extent <- c()
for (i in seq_along(input$extent_layers)) {
  df <- read.csv(input$extent_layers[i]) %>% select("habitat", "extent")
  hab_extent <- rbind(df, hab_extent)
}
print(hab_extent)

hab_health <- c()
for (i in seq_along(input$health_layers)) {
  df <- read.csv(input$health_layers[i]) %>% select("habitat", "health")
  hab_health <- rbind(df, hab_health)
}
print(hab_health)


hab_trend <- c()
for (i in seq_along(input$trend_layers)) {
  df <- read.csv(input$trend_layers[i]) %>% select("habitat", "trend")
  hab_trend <- rbind(df, hab_trend)
}
print(hab_trend)

# join and limit to HAB habitats
hab_filt <- hab_health %>%
  dplyr::full_join(hab_trend, by = c("habitat")) %>%
  dplyr::full_join(hab_extent, by = c("habitat")) %>%
  dplyr::filter(
    habitat %in% c(
      "coral",
      "mangrove",
      "saltmarsh",
      "seaice_edge",
      "seagrass",
      "soft_bottom",
      "kelp",
      "tidal flat",
      "beaches"
    )
  ) %>%
  dplyr::mutate(w = ifelse(!is.na(extent) & extent > 0, 1, NA)) %>%
  dplyr::filter(!is.na(w))
print(hab_filt)

## calculate scores
hab_status <- hab_filt %>%
  # dplyr::group_by(region_id) %>% - don't need this because it is only one region
  dplyr::filter(!is.na(health)) %>%
  dplyr::summarize(
    score = pmin(1, sum(health) / sum(w)) * 100,
    dimension = "status"
  )
print(hab_status)

hab_trend <- hab_filt %>%
  #  dplyr::group_by(region_id) %>%
  dplyr::filter(!is.na(trend)) %>%
  dplyr::summarize(
    score = sum(trend) / sum(w),
    dimension = "trend"
  )
print(hab_trend)


scores_HAB <- rbind(hab_status, hab_trend) %>%
  dplyr::mutate(goal = "HAB") %>%
  dplyr::select(goal, score, dimension)
print(scores_HAB)

hab_score_path <- file.path(outputFolder, "hab_score.csv")
write.csv(scores_HAB, hab_score_path)
biab_output("habitat_score", hab_score_path)



weights <- hab_extent %>%
  filter(
    habitat %in% c(
      "seagrass",
      "saltmarsh",
      "mangrove",
      "coral",
      "seaice_edge",
      "soft_bottom",
      "kelp",
      "tidal flat",
      "beaches"
    )
  ) %>%
  dplyr::filter(extent > 0) %>%
  dplyr::mutate(boolean = 1) %>%
  dplyr::mutate(layer = "element_wts_hab_pres_abs") %>%
  dplyr::select(rgn_id = habitat, boolean, layer)

# output weights
print(weights)

hab_weights_path <- file.path(outputFolder, "hab_weights.csv")
write.csv(weights, hab_weights_path)
biab_output("habitat_weights", hab_weights_path)

# return scores


spp_status <- read.csv(input$spp_status) %>% 
  dplyr::mutate(dimension = "status") %>%
  dplyr::mutate(score = value * 100) %>% select(score, dimension)

# AlignDataYears(layer_nm = "spp_status", layers_obj = layers) %>%
#    dplyr::filter(scenario_year == scen_year) %>%
#     dplyr::select(region_id = rgn_id,
#                   score) %>%
#   dplyr::mutate(dimension = "status") %>%
#   dplyr::mutate(score = score * 100)

spp_trend <- read.csv(input$spp_trend) %>% dplyr::select(
                score = value) %>%
  dplyr::mutate(dimension = "trend")
print(spp_trend)
# layers$data$spp_trend %>%
#   dplyr::select(region_id = rgn_id,
#                 score) %>%
#   dplyr::mutate(dimension = "trend")

spp_scores <- rbind(spp_status, spp_trend) %>%
  dplyr::mutate(goal = "SPP") %>%
  dplyr::select(goal, score, dimension)


print(spp_scores)
spp_score_path <- file.path(outputFolder, "species_score.csv")
write.csv(spp_scores, spp_score_path)
biab_output("species_score", spp_score_path)

# combine status and trend into biodiversity goal
bd_scores <- rbind(spp_scores, scores_HAB) %>%
#  dplyr::filter(goal %in% c("HAB", "SPP")) %>%
 # dplyr::filter(!(dimension %in% c("pressures", "resilience"))) %>%
  dplyr::group_by(dimension) %>%
  dplyr::summarize(score = mean(score, na.rm = TRUE)) %>%
  dplyr::mutate(goal = "BD") %>%
  data.frame()
print(bd_scores)

bd_score_path <- file.path(outputFolder, "bd_score.csv")
write.csv(bd_scores, spp_score_path)
biab_output("species_score", spp_score_path)

