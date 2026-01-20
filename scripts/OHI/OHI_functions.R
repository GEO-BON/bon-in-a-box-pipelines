## These are functions pulled from https://github.com/OHI-Science/ohi-global/blob/draft/eez/conf/functions.R and customized to run in BON in a Box.
library(tidyverse)

HAB <- function(layers) {
  scen_year <- layers$data$scenario_year
  
  # Loading the layers (this will be a csv array with the habitat and the value, don't neeed region ID because it is only for your region of interest)
  extent_lyrs <- input$extent_layers
  

  health_lyrs <- input$health_layers
 

  trend_lyrs <- input$trend_layers


  # get data together: read in csvs and rbind
  extent <- extent_lyrs %>%
  lapply(read_csv, show_col_types = FALSE) %>%
  bind_rows()
  
  health <- health_lyrs %>%
  lapply(read_csv, show_col_types = FALSE) %>%
  bind_rows()
  
  trend <- trend_lyrs %>%
  lapply(read_csv, show_col_types = FALSE) %>%
  bind_rows()
  
  # join and limit to HAB habitats
  d <- health %>%
    dplyr::full_join(trend, by = c('region_id', 'habitat')) %>%
    dplyr::full_join(extent, by = c('region_id', 'habitat')) %>%
    dplyr::filter(
      habitat %in% c(
        'corals',
        'mangrove',
        'saltmarsh',
        'seaice_edge',
        'seagrass',
        'soft_bottom',
        'kelp',
        'tidal flat',
        'beaches'
      )
    ) %>%
    dplyr::mutate(w  = ifelse(!is.na(extent) & extent > 0, 1, NA)) %>%
    dplyr::filter(!is.na(w))
  
#   if (sum(d$w %in% 1 & is.na(d$trend)) > 0) {
#     warning(
#       "Some regions/habitats have extent data, but no trend data.  Consider estimating these values."
#     )
#   }
  
#   if (sum(d$w %in% 1 & is.na(d$health)) > 0) {
#     warning(
#       "Some regions/habitats have extent data, but no health data.  Consider estimating these values."
#     )
#   }
  
  
  ## calculate scores
  status <- d %>%
    #dplyr::group_by(region_id) %>% - don't need this because it is only one region
    dplyr::filter(!is.na(health)) %>%
    dplyr::summarize(score = pmin(1, sum(health) / sum(w)) * 100,
              dimension = 'status') %>%
    ungroup()
  
  trend <- d %>%
    dplyr::group_by(region_id) %>%
    dplyr::filter(!is.na(trend)) %>%
    dplyr::summarize(score =  sum(trend) / sum(w),
              dimension = 'trend')  %>%
    dplyr::ungroup()
  
  scores_HAB <- rbind(status, trend) %>%
    dplyr::mutate(goal = "HAB") %>%
    dplyr::select(goal, score)
  
  ## Reference Point Accounting
#   WriteRefPoint(goal = "HAB",
#                 method = "Health/condition variable based on current vs. historic extent",
#                 ref_pt = "varies for each region/habitat")
  ## Reference Point End    
  
  ## create weights file for pressures/resilience calculations
  
  weights <- extent %>%
    filter(
      habitat %in% c(
        'seagrass',
        'saltmarsh',
        'mangrove',
        'coral',
        'seaice_edge',
        'soft_bottom',
        'kelp',
        'tidal flat',
        'beaches'
      )
    ) %>%
    dplyr::filter(extent > 0) %>%
    dplyr::mutate(boolean = 1) %>%
    dplyr::mutate(layer = "element_wts_hab_pres_abs") %>%
    dplyr::select(rgn_id = region_id, habitat, boolean, layer)
  
  # output weights
  write.csv(weights,
            sprintf(here("eez/temp/element_wts_hab_pres_abs_%s.csv"), scen_year),
            row.names = FALSE)
  
  layers$data$element_wts_hab_pres_abs <- weights
  
  
  # return scores
  return(scores_HAB)
}


SPP <- function(layers) {

 # scen_year <- layers$data$scenario_year
  
status <- read.csv(input$spp_status) %>% 
  dplyr::mutate(dimension = "status") %>%
  dplyr::mutate(score = score * 100)

#AlignDataYears(layer_nm = "spp_status", layers_obj = layers) %>%
#    dplyr::filter(scenario_year == scen_year) %>%
#     dplyr::select(region_id = rgn_id,
#                   score) %>%
#   dplyr::mutate(dimension = "status") %>%
#   dplyr::mutate(score = score * 100)
  
trend <- read.csv(input$spp_trend)
#layers$data$spp_trend %>%
#   dplyr::select(region_id = rgn_id,
#                 score) %>%
#   dplyr::mutate(dimension = "trend")

scores <- rbind(status, trend) %>%
    dplyr::mutate(goal = 'SPP') %>%
    dplyr::select(goal, score)
  
  
  return(scores)
}

BD <- function(scores) {
  d <- scores %>%
    dplyr::filter(goal %in% c('HAB', 'SPP')) %>%
    dplyr::filter(!(dimension %in% c('pressures', 'resilience'))) %>%
    dplyr::group_by(region_id, dimension) %>%
    dplyr::summarize(score = mean(score, na.rm = TRUE)) %>%
    dplyr::mutate(goal = 'BD') %>%
    data.frame()
  
  # return all scores
  return(rbind(scores, d[, c('region_id', 'goal', 'dimension', 'score')]))
}