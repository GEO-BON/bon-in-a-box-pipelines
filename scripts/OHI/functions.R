## functions.R.
## Each OHI goal model is a separate R function.
## The function name is the 2- or 3- letter code for each goal or subgoal;
## for example, FIS is the Fishing subgoal of Food Provision (FP).


FIS <- function(layers) {
 
  scen_year <- layers$data$scenario_year
  
  #catch data
  c <-
    AlignDataYears(layer_nm = "fis_meancatch", layers_obj = layers) %>%
    dplyr::select(
      region_id = rgn_id,
      year = scenario_year,
      stock_id_taxonkey,
      catch = mean_catch
    )
  
  #  b_bmsy data
  
  b <-
    AlignDataYears(layer_nm = "fis_b_bmsy", layers_obj = layers) %>%
    dplyr::select(region_id = rgn_id, stock_id, year = scenario_year, bbmsy)
  
  ## The following code is commented out because we removed the underharvest penalty for v2021. I am leaving the commented out code in the script for future reference, if we want to implement something similar. 
  # The following stocks are fished in multiple regions and often have high b/bmsy values
  # Due to the underfishing penalty, this actually penalizes the regions that have the highest
  # proportion of catch of these stocks.  
  
  # high_bmsy_filter <- dplyr::filter(b, bbmsy>1.5 & year == 2015) %>%
  #   dplyr::group_by(stock_id) %>%
  #   dplyr::summarise(n = dplyr::n()) %>%
  #   data.frame() %>%
  #   dplyr::filter(n>3)
  # 
  #  high_bmsy <- high_bmsy_filter$stock_id

   # b <- b %>%
   #   dplyr::mutate(bbmsy = ifelse(stock_id %in% high_bmsy &
   #                           bbmsy > 1, 1, bbmsy))

   # # Do not apply an underharvest penalty! Cap bbmsy at 1. 
   b <- b %>%
     dplyr::mutate(bbmsy = ifelse(bbmsy > 1, 1, bbmsy))
  
  
  # separate out the stock_id and taxonkey:
  c <- c %>%
    dplyr::mutate(stock_id_taxonkey = as.character(stock_id_taxonkey)) %>%
    dplyr::mutate(taxon_key = sub('.*_', '', stock_id_taxonkey)) %>%
    dplyr::mutate(stock_id = sub('_[^_]*$', '', stock_id_taxonkey)) %>%
    dplyr::mutate(catch = as.numeric(catch)) %>%
    dplyr::mutate(year = as.numeric(as.character(year))) %>%
    dplyr::mutate(region_id = as.numeric(as.character(region_id))) %>%
    dplyr::mutate(taxon_key = as.numeric(as.character(taxon_key))) %>%
    dplyr::select(region_id, year, stock_id, taxon_key, catch)
  
  # general formatting:
  b <- b %>%
    dplyr::mutate(bbmsy = as.numeric(bbmsy)) %>%
    dplyr::mutate(region_id = as.numeric(as.character(region_id))) %>%
    dplyr::mutate(year = as.numeric(as.character(year))) %>%
    dplyr::mutate(stock_id = as.character(stock_id))
  
  
  ## Note: We can probably ignore the upper buffer now.. since we cap all scores at 1 anyways above. 
  ####
  # STEP 1. Calculate scores for Bbmsy values
  ####
  #  *************NOTE *****************************
  #  These values can be altered
  #  ***********************************************
  alpha <- 0.5
  beta <- 0.25
  lowerBuffer <- 0.95
  upperBuffer <- 1.05
  
  b$score = ifelse(
    b$bbmsy < lowerBuffer,
    b$bbmsy,
    ifelse (b$bbmsy >= lowerBuffer &
              b$bbmsy <= upperBuffer, 1, NA)
  )
  b$score = ifelse(!is.na(b$score),
                   b$score,
                   ifelse(
                     1 - alpha * (b$bbmsy - upperBuffer) > beta,
                     1 - alpha * (b$bbmsy - upperBuffer),
                     beta
                   ))
  
  
  ####
  # STEP 1. Merge the b/bmsy data with catch data
  ####
  data_fis <- c %>%
    dplyr::left_join(b, by = c('region_id', 'stock_id', 'year')) %>%
    dplyr::select(region_id, stock_id, year, taxon_key, catch, bbmsy, score)
  
  
  ###
  # STEP 2. Estimate scores for taxa without b/bmsy values
  # Mean score of other fish in the region is the starting point
  # Then a penalty is applied based on the level the taxa are reported at
  ###
  
  ## this takes the mean score within each region and year
  ## assessments prior to 2018 used the median
  data_fis_gf <- data_fis %>%
    dplyr::group_by(region_id, year) %>%
    dplyr::mutate(mean_score = mean(score, na.rm = TRUE)) %>%
    dplyr::ungroup()
  
  ## this takes the mean score across all regions within a year
  # (when no stocks have scores within a region)
  data_fis_gf <- data_fis_gf %>%
    dplyr::group_by(year) %>%
    dplyr::mutate(mean_score_global = mean(score, na.rm = TRUE)) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(mean_score = ifelse(is.na(mean_score), mean_score_global, mean_score)) %>%
    dplyr::select(-mean_score_global)
  
  #  *************NOTE *****************************
  #  In some cases, it may make sense to alter the
  #  penalty for not identifying fisheries catch data to
  #  species level.
  #  ***********************************************
  
  penaltyTable <- data.frame(TaxonPenaltyCode = 1:6,
                             penalty = c(0.1, 0.25, 0.5, 0.8, 0.9, 1))
  
  data_fis_gf <- data_fis_gf %>%
    dplyr::mutate(TaxonPenaltyCode = as.numeric(substring(taxon_key, 1, 1))) %>%
    dplyr::left_join(penaltyTable, by = 'TaxonPenaltyCode') %>%
    dplyr::mutate(score_gf = mean_score * penalty) %>%
    dplyr::mutate(method = ifelse(is.na(score), "Mean gapfilled", NA)) %>%
    dplyr::mutate(gapfilled = ifelse(is.na(score), 1, 0)) %>%
    dplyr::mutate(score = ifelse(is.na(score), score_gf, score))
  
  
  gap_fill_data <- data_fis_gf %>%
    dplyr::select(region_id,
           stock_id,
           taxon_key,
           year,
           catch,
           score,
           gapfilled,
           method) %>%
    dplyr::filter(year == scen_year) 
  
  write.csv(gap_fill_data, here('eez/temp/FIS_summary_gf.csv'), row.names = FALSE)
  
  status_data <- data_fis_gf %>%
    dplyr::select(region_id, stock_id, year, catch, score)
  
  
  ###
  # STEP 4. Calculate status for each region
  ###
  
  # 4a. To calculate the weight (i.e, the relative catch of each stock per region),
  # the mean catch of taxon i is divided by the
  # sum of mean catch of all species in region/year
  
  status_data <- status_data %>%
    dplyr::group_by(year, region_id) %>%
    dplyr::mutate(SumCatch = sum(catch)) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(wprop = catch / SumCatch)  
  
  status_data <- status_data %>%
    dplyr::group_by(region_id, year) %>%
    dplyr::summarize(status = prod(score ^ wprop)) %>%
    dplyr::ungroup()
  

  ###
  # STEP 5. Get yearly status and trend
  ###
  
  status <-  status_data %>%
    dplyr::filter(year == scen_year) %>%
    dplyr::mutate(score     = round(status * 100, 1),
           dimension = 'status') %>%
    dplyr::select(region_id, score, dimension)
  
  
  # calculate trend
  
  trend_years <- (scen_year - 4):(scen_year)
  
  trend <-
    CalculateTrend(status_data = status_data, trend_years = trend_years)
  
  ## Reference Point Accounting
  WriteRefPoint(goal   = "FIS",
                method = "Functional relationship (B/Bmsy)",
                ref_pt = NA)
  ## Reference Point End
  
  # assemble dimensions
  scores <- rbind(status, trend) %>%
    dplyr::mutate(goal = 'FIS') %>%
    dplyr::filter(region_id != 255)
  scores <- data.frame(scores)
  
  return(scores)
}


MAR <- function(layers) {
  scen_year <- layers$data$scenario_year
  harvest_tonnes <-
    AlignDataYears(layer_nm = "mar_harvest_tonnes", layers_obj = layers)
  
  sustainability_score <-
    AlignDataYears(layer_nm = "mar_sustainability_score", layers_obj = layers)
  
  reference_point <- 
    AlignDataYears(layer_nm = "mar_capacity", layers_obj = layers)
  
  rky <-  harvest_tonnes %>%
    dplyr::left_join(sustainability_score,
              by = c('rgn_id', 'taxa_code', 'scenario_year')) %>%
    dplyr::select(rgn_id, scenario_year, taxa_code, taxa_group, tonnes, sust_coeff)
  
  # fill in gaps with no data
  rky <- tidyr::spread(rky, scenario_year, tonnes)
  rky <- tidyr::gather(rky, "scenario_year", "tonnes",-(1:4)) %>%
    dplyr::mutate(scenario_year = as.numeric(scenario_year))
  
  # adjustment for seaweeds based on protein content
  rky <- rky %>%
    #dplyr::mutate(tonnes = ifelse(taxa_group == "AL", tonnes*0.2, tonnes)) %>%
    dplyr::select(-taxa_group)
  
  # 4-year rolling mean of data
  m <- rky %>%
    dplyr::group_by(rgn_id, taxa_code, sust_coeff) %>%
    dplyr::arrange(rgn_id, taxa_code, scenario_year) %>%
    dplyr::mutate(sm_tonnes = zoo::rollapply(tonnes, 4, mean, na.rm = TRUE, partial =
                                        TRUE, align = "right")) %>%
    dplyr::ungroup() %>%
    mutate(sm_tonnes = ifelse(sm_tonnes == "NaN", 0, sm_tonnes))
  
  
  # aggregate all weighted timeseries per region, and divide by potential mariculture
  
  tonnes_pot_div <- m %>%
    dplyr::group_by(rgn_id, scenario_year) %>%
    dplyr::summarize(tonnes_sum = sum(sm_tonnes, na.rm = TRUE)) %>%  #na.rm = TRUE assumes that NA values are 0
    dplyr::left_join(reference_point, by = c('rgn_id', 'scenario_year')) %>%
    dplyr::mutate(tonnes_score = tonnes_sum / potential_mar_tonnes) %>%
    dplyr::ungroup() 
    
    sustainability <- m %>%
    dplyr::group_by(rgn_id, scenario_year) %>%
    dplyr::summarise(sust_rgn = weighted.mean(x = sust_coeff, w = sm_tonnes, na.rm = TRUE)) %>%
    dplyr::ungroup()
  
    ry <- sustainability %>%
      dplyr::left_join(tonnes_pot_div) %>%
      dplyr::mutate(status = ifelse(tonnes_score > 1,
                                    1,
                                    tonnes_score)) %>%
      dplyr::mutate(status = sust_rgn*status)
    
  
  ## add in methods to deal with weirdness
  
   WriteRefPoint(
    goal = "MAR",
    method = "Biological capacity of region to produce mariculture",
    ref_pt = "Varies by region, see Gentry et al. 2017")
  ## Reference Point End
  
  ry = ry %>%
    dplyr::mutate(status = ifelse(is.na(status),
                                  0,
                                  status)) %>%
    dplyr::mutate(status = ifelse(tonnes_sum < 100 & potential_mar_tonnes < 100,
                  NA,
                  status))
  
  ## Add all other regions/countries with no mariculture production to the data table
  ## Uninhabited or low population countries that don't have mariculture, should be given a NA since they are too small to ever be able to produce and sustain a mariculture industry.
  ## Countries that have significant population size and fishing activity (these two are proxies for having the infrastructure capacity to develop mariculture), but don't produce any mariculture, are given a '0'.
  all_rgns <- expand.grid(rgn_id = georegions$rgn_id, scenario_year = min(ry$scenario_year):max(ry$scenario_year))
  
  all_rgns <- all_rgns[!(all_rgns$rgn_id %in% ry$rgn_id),]
  
  uninhabited <- read.csv("https://raw.githubusercontent.com/OHI-Science/ohiprep/master/globalprep/spatial/v2017/output/rgn_uninhabited_islands.csv")
  
  uninhabited <- uninhabited %>% 
    dplyr::filter(rgn_nam != "British Indian Ocean Territory") # remove British Indian Ocean Territory which has fishing activity and a population size of 3000 inhabitants
  
  ## Combine all regions with mariculture data table
  ry_all_rgns <- all_rgns %>% 
    dplyr::mutate(status = 0) %>% 
    dplyr::mutate(status = ifelse(rgn_id %in% uninhabited$rgn_id, NA, status)) %>% 
    dplyr::bind_rows(ry) %>% 
    dplyr::arrange(rgn_id)
  
  
  status <- ry_all_rgns %>%
    dplyr::filter(scenario_year == scen_year) %>%
    dplyr::mutate(dimension = "status") %>%
    dplyr::select(region_id = rgn_id, score = status, dimension) %>%
    dplyr::mutate(score = round(score * 100, 2))
  
  
  # calculate trend
  
  trend_years <- (scen_year - 4):(scen_year)
  
  trend <- CalculateTrend(status_data = dplyr::filter(ry_all_rgns, !is.na(status)), trend_years = trend_years)
  
  
  # return scores
  scores = rbind(status, trend) %>%
    dplyr::mutate(goal = 'MAR')
  
  return(scores)
}


FP <- function(layers, scores) {
 
  scen_year <- layers$data$scenario_year
  
  w <-
    AlignDataYears(layer_nm = "fp_wildcaught_weight", layers_obj = layers) %>%
    dplyr::filter(scenario_year == scen_year) %>%
    dplyr::select(region_id = rgn_id, w_fis)
  
  # scores
  s <- scores %>%
    dplyr::filter(goal %in% c('FIS', 'MAR')) %>%
    dplyr::filter(!(dimension %in% c('pressures', 'resilience'))) %>%
    dplyr::left_join(w, by = "region_id")  %>%
    dplyr::mutate(w_mar = 1 - w_fis) %>%
    dplyr::mutate(weight = ifelse(goal == "FIS", w_fis, w_mar))
  
  
  ## Some warning messages due to potential mismatches in data:
  ## In the future consider filtering by scenario year so it's easy to see what warnings are attributed to which data
  # NA score but there is a weight
  tmp <-
    dplyr::filter(s,
           goal == 'FIS' &
             is.na(score) & (!is.na(w_fis) & w_fis != 0) & dimension == "score")
  if (dim(tmp)[1] > 0) {
    warning(paste0(
      "Check: these regions have a FIS weight but no score: ",
      paste(as.character(tmp$region_id), collapse = ", ")
    ))
  }
  
  tmp <-
    dplyr::filter(s,
           goal == 'MAR' &
             is.na(score) & (!is.na(w_mar) & w_fis != 0) & dimension == "score")
  if (dim(tmp)[1] > 0) {
    warning(paste0(
      "Check: these regions have a MAR weight but no score: ",
      paste(as.character(tmp$region_id), collapse = ", ")
    ))
  }
  
  # score, but the weight is NA or 0
  tmp <-
    dplyr::filter(
      s,
      goal == 'FIS' &
        (!is.na(score) &
           score > 0) &
        (is.na(w_fis) | w_fis == 0) & dimension == "score" & region_id != 0
    )
  if (dim(tmp)[1] > 0) {
    warning(paste0(
      "Check: these regions have a FIS score but weight is NA or 0: ",
      paste(as.character(tmp$region_id), collapse = ", ")
    ))
  }
  
  tmp <-
    dplyr::filter(
      s,
      goal == 'MAR' &
        (!is.na(score) &
           score > 0.05) &
        (is.na(w_mar) | w_mar == 0) & dimension == "score" & region_id != 0
    )
  if (dim(tmp)[1] > 0) {
    warning(paste0(
      "Check: these regions have a MAR score but weight is NA or 0: ",
      paste(as.character(tmp$region_id), collapse = ", ")
    ))
  }
  
  s <- s  %>%
    dplyr::group_by(region_id, dimension) %>%
    dplyr::summarize(score = weighted.mean(score, weight, na.rm = TRUE)) %>%
    dplyr::mutate(goal = "FP") %>%
    dplyr::ungroup() %>%
    dplyr::select(region_id, goal, dimension, score) %>%
    data.frame()
  
  # return all scores
  return(rbind(scores, s))
}


AO <- function(layers) {
  # Sustainability <- 1.0
  scen_year <- layers$data$scenario_year

  r <- AlignDataYears(layer_nm = "ao_access", layers_obj = layers) %>%
    dplyr::rename(region_id = rgn_id, access = value) %>%
    na.omit()
  
  sust <- AlignDataYears(layer_nm = "ao_sust", layers_obj = layers) %>%
    dplyr::rename(region_id = rgn_id, sust = score)
  
  ry <-
    AlignDataYears(layer_nm = "ao_need", layers_obj = layers) %>%
    dplyr::rename(region_id = rgn_id, need = value) %>%
    dplyr::left_join(r, by = c("region_id", "scenario_year")) %>%
    dplyr::left_join(sust, by = c("region_id", "scenario_year"))
  
  # model
  ry <- ry %>%
    dplyr::mutate(sust = ifelse(is.na(sust), access, sust)) %>%
    dplyr::mutate(Du = (1 - need) * (1 - access)) %>%
    dplyr::mutate(status = (1 - Du) * sust)
  
  # status
  r.status <- ry %>%
    dplyr::filter(scenario_year == scen_year) %>%
    dplyr::select(region_id, status) %>%
    dplyr::mutate(status = status * 100) %>%
    dplyr::select(region_id, score = status) %>%
    dplyr::mutate(dimension = 'status')
  
  # trend
  
  trend_years <- (scen_year - 4):(scen_year)
  
  r.trend <- CalculateTrend(status_data = ry, trend_years = trend_years)
  
## Reference Point Accounting
    WriteRefPoint(goal   = "AO",
                method = "XXXXXXXX",
                ref_pt = NA)
 ## Reference Point End
    
  # return scores
  scores <- rbind(r.status, r.trend) %>%
    dplyr::mutate(goal = 'AO')
  
  return(scores)
}

NP <- function(scores, layers) {

      scen_year <- layers$data$scenario_year
  
  
    #### Ornamentals 
    np_ornamentals_score <-
      AlignDataYears(layer_nm = "np_ornamental_sust", layers_obj = layers) %>%
      dplyr::select(year = scenario_year, region_id = rgn_id, orns_score=score)
    np_ornamentals_weights <-
      AlignDataYears(layer_nm = "np_ornamental_weights", layers_obj = layers) %>%
      dplyr::select(year = scenario_year, region_id = rgn_id, orns_weight = usd_weight)
    

    ### Seaweeds
    np_seaweed_score <- 
      AlignDataYears(layer_nm = "np_seaweed_sust", layers_obj = layers) %>%
      dplyr::select(year = scenario_year, region_id = rgn_id, seaweed_score=rel_sust_tonnes, 
                    ) 
    
    np_seaweed_weights <-
      AlignDataYears(layer_nm = "np_seaweed_weights", layers_obj = layers) %>%
      dplyr::select(year = scenario_year, region_id = rgn_id, seaweed_weight=usd_weight)
    

    ### FOFM
    np_fofm_scores <- 
      AlignDataYears(layer_nm = "np_fofm_sust", layers_obj = layers) %>%
      dplyr::select(year = scenario_year, region_id = rgn_id, fofm_score=score) 

    np_fofm_weights <-
      AlignDataYears(layer_nm = "np_fofm_weights", layers_obj = layers) %>%
      dplyr::select(year = scenario_year, region_id = rgn_id, fofm_weight=usd_weight)
    


    ### Calculate status, trends
    ### aggregate across products to rgn-year status, weighting by usd_rel
    np_weights <- full_join(np_fofm_weights, np_seaweed_weights, by=c("region_id", "year")) %>%
      full_join(np_ornamentals_weights, by=c("region_id", "year")) %>%
      mutate(across(where(is.numeric), ~ replace_na(.x, 0)))
    
    np_scores <- full_join(np_fofm_scores, np_seaweed_score, by=c("region_id", "year")) %>%
      full_join(np_ornamentals_score, by=c("region_id", "year")) %>%
      mutate(across(where(is.numeric), ~ replace_na(.x, 0))) 
    
    total <- left_join(np_scores, np_weights, by=c("region_id", "year")) 
    
    total <- total %>%
      # gather to long (metric = fofm/seaweed/orns; kind = score/weight)
      pivot_longer(
        cols = matches("^(fofm|seaweed|orns)_(score|weight)$"),
        names_to = c("metric", "kind"),
        names_pattern = "(fofm|seaweed|orns)_(score|weight)",
        values_to = "val"
      ) %>%
      pivot_wider(names_from = kind, values_from = val) %>%  # -> columns: score, weight
      group_by(year, region_id) %>%
      summarise(status = weighted.mean(score, weight)) %>%
      ungroup()
    
    ### get current status
    np_status_current <- total %>%
      filter(year == scen_year & !is.na(status)) %>%
      mutate(dimension = 'status',
             score     = round(status, 4) * 100) %>%
      select(region_id, dimension, score)
    stopifnot(
      min(np_status_current$score, na.rm = TRUE) >= 0,
      max(np_status_current$score, na.rm = TRUE) <= 100
    )
    
    ### trend
    
    trend_years <- (scen_year - 4):(scen_year)
    
    np_trend <-
      CalculateTrend(status_data = total, trend_years = trend_years)
    
    ### return scores
    np_scores <- np_status_current %>%
      full_join(np_trend, by = c('region_id', 'dimension', 'score')) %>%
      mutate(goal = 'NP') %>%
      select(goal, dimension, region_id, score) %>%
      arrange(goal, dimension, region_id)
    

  ## Reference Point Accounting
  WriteRefPoint(goal = "NP",
                method = "Harvest peak within region times 0.65 buffer",
                ref_pt = "varies for each item")
  ## Reference Point End  
  #browser()
  ## create weights file for pressures/resilience calculations
  
  #weights <- extent %>%
   # filter(
    #  habitat %in% c(
     #   'seagrass',
      #  'saltmarsh',
       # 'mangrove',
        #'coral',
        #'seaice_edge',
      #  'soft_bottom',
      #  'kelp',
      #  'tidal flat',
      #  'beaches'
    #  )
    # ) %>%
    #dplyr::filter(extent > 0) %>%
    #dplyr::mutate(boolean = 1) %>%
    #dplyr::mutate(layer = "element_wts_hab_pres_abs") %>%
    #dplyr::select(rgn_id = region_id, habitat, boolean, layer)
  
#  write.csv(weights,
 #           sprintf(here("eez/temp/element_wts_hab_pres_abs_%s.csv"), scen_year),
  #          row.names = FALSE)
  
  #layers$data$element_wts_hab_pres_abs <- weights
  
  
  
  return(np_scores)
}


CS <- function(layers) {

  scen_year <- layers$data$scenario_year
  
  # layers for carbon storage
  extent_lyrs <-
    c('hab_mangrove_extent',
      'hab_seagrass_extent',
      'hab_saltmarsh_extent',
      'hab_tidal_flat_extent')
  health_lyrs <-
    c('hab_mangrove_health',
      'hab_seagrass_health',
      'hab_saltmarsh_health',
      'hab_tidal_flat_health')
  trend_lyrs <-
    c('hab_mangrove_trend',
      'hab_seagrass_trend',
      'hab_saltmarsh_trend',
      'hab_tidal_flat_trend')
  
  # get data together:
  extent <- AlignManyDataYears(extent_lyrs) %>%
    # mangrove inland 1km and offshore removed for v2021
    # dplyr::filter(!(habitat %in% c(
    #   "mangrove_inland1km", "mangrove_offshore" 
    # ))) %>%
    dplyr::filter(scenario_year == scen_year) %>%
    dplyr::select(region_id = rgn_id, habitat, extent = km2) %>%
    dplyr::mutate(habitat = as.character(habitat))
  
  health <- AlignManyDataYears(health_lyrs) %>%
    # mangrove inland 1km and offshore removed for v2021
    # dplyr::filter(!(habitat %in% c(
    #   "mangrove_inland1km", "mangrove_offshore"
    # ))) %>%
    dplyr::filter(scenario_year == scen_year) %>%
    dplyr::select(region_id = rgn_id, habitat, health) %>%
    dplyr::mutate(habitat = as.character(habitat))
  
  trend <- AlignManyDataYears(trend_lyrs) %>%
    # mangrove inland 1km and offshore removed for v2021
    # dplyr::filter(!(habitat %in% c(
    #   "mangrove_inland1km", "mangrove_offshore"
    # ))) %>%
    dplyr::filter(scenario_year == scen_year) %>%
    dplyr::select(region_id = rgn_id, habitat, trend) %>%
    dplyr::mutate(habitat = as.character(habitat))
  
  ## join layer data
  d <-  extent %>%
    dplyr::full_join(health, by = c("region_id", "habitat")) %>%
    dplyr::full_join(trend, by = c("region_id", "habitat"))
  
  ## set ranks for each habitat
  habitat.rank <- c('mangrove'   = 230.9,
                    'saltmarsh'  = 244.7,
                    'seagrass'   = 138,
                    'tidal flat' = 129.8)
  
  ## limit to CS habitats and add rank
  d <- d %>%
    dplyr::mutate(rank = habitat.rank[habitat],
           extent = ifelse(extent == 0, NA, extent))
  
  # status
  status <- d %>%
    dplyr::filter(!is.na(rank) & !is.na(health) & !is.na(extent)) %>%
    dplyr::group_by(region_id) %>%
    dplyr::summarize(score = pmin(1, sum(rank * health * extent, na.rm = TRUE) / (sum(
      extent * rank, na.rm = TRUE
    ))) * 100,
    dimension = 'status') %>%
    ungroup()
  
  # trend
  
  trend <- d %>%
    filter(!is.na(rank) & !is.na(trend) & !is.na(extent)) %>%
    dplyr::group_by(region_id) %>%
    dplyr::summarize(score = sum(rank * trend * extent, na.rm = TRUE) / (sum(extent *
                                                                        rank, na.rm = TRUE)),
              dimension = 'trend') %>%
    dplyr::ungroup()
  
  
  scores_CS <- rbind(status, trend)  %>%
    dplyr::mutate(goal = 'CS') %>%
    dplyr::select(goal, dimension, region_id, score)
  
  ## Reference Point Accounting
  WriteRefPoint(goal = "CS",
                method = "Health/condition variable based on current vs. historic extent",
                ref_pt = "varies for each region/habitat")
  ## Reference Point End  
  
  ## create weights file for pressures/resilience calculations
  weights <- extent %>%
    dplyr::filter(extent > 0) %>%
    dplyr::mutate(rank = habitat.rank[habitat]) %>%
    dplyr::mutate(extent_rank = extent * rank) %>%
    dplyr::mutate(layer = "element_wts_cs_km2_x_storage") %>%
    dplyr::select(rgn_id = region_id, habitat, extent_rank, layer)
  
  write.csv(
    weights,
    sprintf(here("eez/temp/element_wts_cs_km2_x_storage_%s.csv"), scen_year),
    row.names = FALSE
  )
  
  layers$data$element_wts_cs_km2_x_storage <- weights
  
  
  # return scores
  return(scores_CS)
}



CP <- function(layers) {

  ## read in layers
  scen_year <- layers$data$scenario_year
  
  # layers for coastal protection
  extent_lyrs <-
    c(
      'hab_mangrove_extent',
      'hab_seagrass_extent',
      'hab_saltmarsh_extent',
      'hab_coral_extent',
      'hab_seaice_extent',
      'hab_kelp_extent'
    )
  health_lyrs <-
    c(
      'hab_mangrove_health',
      'hab_seagrass_health',
      'hab_saltmarsh_health',
      'hab_coral_health',
      'hab_seaice_health',
      'hab_kelp_health'
      
    )
  trend_lyrs <-
    c(
      'hab_mangrove_trend',
      'hab_seagrass_trend',
      'hab_saltmarsh_trend',
      'hab_coral_trend',
      'hab_seaice_trend',
      'hab_kelp_trend'
    )


  # get data together:
  extent <- AlignManyDataYears(extent_lyrs) %>%
    dplyr::filter(!(habitat %in% "seaice_edge")) %>%
    dplyr::filter(scenario_year == scen_year) %>%
    dplyr::select(region_id = rgn_id, habitat, extent = km2) %>%
    dplyr::mutate(habitat = as.character(habitat))
  
  health <- AlignManyDataYears(health_lyrs) %>%
    dplyr::filter(!(habitat %in% "seaice_edge")) %>%
    dplyr::filter(scenario_year == scen_year) %>%
    dplyr::select(region_id = rgn_id, habitat, health) %>%
    dplyr::mutate(habitat = as.character(habitat))
  
  trend <- AlignManyDataYears(trend_lyrs) %>%
    dplyr::filter(!(habitat %in% "seaice_edge")) %>%
    dplyr::filter(scenario_year == scen_year) %>%
    dplyr::select(region_id = rgn_id, habitat, trend) %>%
    dplyr::mutate(habitat = as.character(habitat))
  
  ## sum mangrove_offshore + mangrove_inland1km = mangrove to match with extent and trend - removed v2021.. unnecessary code anyways
  # mangrove_extent <- extent %>%
  #   dplyr::filter(habitat %in% c('mangrove_inland1km', 'mangrove_offshore'))
  
  # if (nrow(mangrove_extent) > 0) {
  #   mangrove_extent <- mangrove_extent %>%
  #     dplyr::group_by(region_id) %>%
  #     dplyr::summarize(extent = sum(extent, na.rm = TRUE)) %>%
  #     dplyr::mutate(habitat = 'mangrove') %>%
  #     dplyr::ungroup()
  # }
  # 
  # extent <- extent %>%
  #   dplyr::filter(!habitat %in% c('mangrove', 'mangrove_inland1km', 'mangrove_offshore')) %>%  #do not use all mangrove
  #   rbind(mangrove_extent)  #just the inland 1km and offshore
  
  ## join layer data
  d <-  extent %>%
    dplyr::full_join(health, by = c("region_id", "habitat")) %>%
    dplyr::full_join(trend, by = c("region_id", "habitat"))
  
  # Removing countries within the Baltic, Iceland, and North Sea regions (UK, Germany, Denmark) 
  # because seaice edge is due to ice floating into the environment and does not provide coastal protection
  # for these regions
  
  floaters <- c(174, 178, 222, 70, 69, 189, 143, 180, 176, 175)
  
  
   d <- d %>%
    dplyr::filter(!(region_id %in% floaters & habitat == "seaice_shoreline"))
  
  ## set ranks for each habitat
  habitat.rank <- c(
    'coral'            = 3,
    'mangrove'         = 4,
    'saltmarsh'        = 4,
    'seagrass'         = 1,
    'seaice_shoreline' = 4,
    'kelp' = 1
  )
  
  ## limit to CP habitats and add rank
  d <- d %>%
    dplyr::filter(habitat %in% names(habitat.rank)) %>%
    dplyr::mutate(rank = habitat.rank[habitat],
           extent = ifelse(extent == 0, NA, extent))
  
  
  # status
  scores_CP <- d %>%
    dplyr::filter(!is.na(rank) & !is.na(health) & !is.na(extent)) %>%
    dplyr::group_by(region_id) %>%
    dplyr::summarize(score = pmin(1, sum(rank * health * extent, na.rm = TRUE) /
                             (sum(
                               extent * rank, na.rm = TRUE
                             ))) * 100) %>%
    dplyr::mutate(dimension = 'status') %>%
    ungroup()
  
  # trend
  d_trend <- d %>%
    dplyr::filter(!is.na(rank) & !is.na(trend) & !is.na(extent))
  
  if (nrow(d_trend) > 0) {
    scores_CP <- dplyr::bind_rows(
      scores_CP,
      d_trend %>%
        dplyr::group_by(region_id) %>%
        dplyr::summarize(
          score = sum(rank * trend * extent, na.rm = TRUE) / (sum(extent * rank, na.rm =
                                                                    TRUE)),
          dimension = 'trend'
        )
    )
  } else {
    # if no trend score, assign NA
    scores_CP <- dplyr::bind_rows(scores_CP,
                                  d %>%
                                    dplyr::group_by(rgn_id) %>%
                                    dplyr::summarize(score = NA,
                                              dimension = 'trend'))
  }
  
  ## finalize scores_CP
  scores_CP <- scores_CP %>%
    dplyr::mutate(goal = 'CP') %>%
    dplyr::select(region_id, goal, dimension, score)
  
  ## Reference Point Accounting
  WriteRefPoint(goal = "CP",
                method = "Health/condition variable based on current vs. historic extent",
                ref_pt = "varies for each region/habitat")
  ## Reference Point End  
  
  ## create weights file for pressures/resilience calculations
  
  weights <- extent %>%
    dplyr::filter(extent > 0) %>%
    dplyr::mutate(rank = habitat.rank[habitat]) %>%
    dplyr::mutate(extent_rank = extent * rank) %>%
    dplyr::mutate(layer = "element_wts_cp_km2_x_protection") %>%
    dplyr::select(rgn_id = region_id, habitat, extent_rank, layer)
  
  write.csv(
    weights,
    sprintf(here("eez/temp/element_wts_cp_km2_x_protection_%s.csv"), scen_year),
    row.names = FALSE
  )
  
  layers$data$element_wts_cp_km2_x_protection <- weights
  
  # return scores
  return(scores_CP)
  
}

TR <- function(layers) {
  ## formula:
  ##  A   = Ap                         # Ap: proportions of tourist arrivals to area of coastline. tr_arrivals_props_tourism.csv
  ##  S   = (S_score - 1) / (7 - 1)    # S_score: raw TTCI score, not normalized (1-7). tr_sustainability.csv
  ##  Xtr = A * S
  pct_ref <- 90
  
  scen_year <- layers$data$scenario_year
  
  
  ## read in layers
  tourism <-
    AlignDataYears(layer_nm = "tr_arrivals_props_tourism", layers_obj = layers) %>%
    dplyr::select(-layer_name)
  sustain <-
    AlignDataYears(layer_nm = "tr_sustainability", layers_obj = layers) %>%
    dplyr::select(-layer_name)
  
  tr_data  <-
    dplyr::full_join(tourism, sustain, by = c('rgn_id', 'scenario_year'))
  
  tr_model <- tr_data %>%
    dplyr::mutate(A   = Ap,
           S   = (S_score - 1) / (7 - 1),
           # scale score from 1 to 7.
           Xtr = A * S)


  # assign NA for uninhabitated islands (i.e., islands with <100 people)
  if (conf$config$layer_region_labels == 'rgn_global') {
    unpopulated = layers$data$uninhabited %>%
      dplyr::filter(est_population < 100 | is.na(est_population)) %>%
      dplyr::select(rgn_id)
    tr_model$Xtr = ifelse(tr_model$rgn_id %in% unpopulated$rgn_id,
                            NA,
                          tr_model$Xtr)
  }
  
     
  
  ### Calculate status based on quantile reference (see function call for pct_ref)
  tr_model <- tr_model %>%
    dplyr::filter(scenario_year >=2008) %>%
    dplyr::mutate(Xtr_q = quantile(Xtr, probs = pct_ref / 100, na.rm = TRUE)) %>%
    dplyr::mutate(status  = ifelse(Xtr / Xtr_q > 1, 1, Xtr / Xtr_q)) %>% # rescale to qth percentile, cap at 1
    dplyr::ungroup()
  
  ## Reference Point Accounting
  ref_point <- tr_model %>%
    dplyr::filter(scenario_year == scen_year) %>%
    dplyr::select(Xtr_q) %>%
    unique() %>%
    data.frame() %>%
    .$Xtr_q
  
  WriteRefPoint(
    goal = "TR",
    method = paste0('spatial: ', as.character(pct_ref), "th quantile"),
    ref_pt = as.character(ref_point)
  )
  ## Reference Point End  
  
  # get status
  tr_status <- tr_model %>%
    dplyr::filter(scenario_year == scen_year) %>%
    dplyr::select(region_id = rgn_id, score = status) %>%
    dplyr::mutate(score = score * 100) %>%
    dplyr::mutate(dimension = 'status')
  
  
  # calculate trend
  
  trend_data <- tr_model %>%
    dplyr::filter(!is.na(status))
  
  trend_years <- (scen_year - 4):(scen_year)
  
  tr_trend <-
    CalculateTrend(status_data = trend_data, trend_years = trend_years)
  
  
  # bind status and trend by rows
  tr_score <- dplyr::bind_rows(tr_status, tr_trend) %>%
    dplyr::mutate(goal = 'TR')
  

  # return final scores
  scores <- tr_score %>%
    dplyr::select(region_id, goal, dimension, score)
  
  return(scores)
}


LIV <- function(layers) {

  # NOTE: scripts and related files for calculating these subgoals is located: 
  # eez/archive
  # These data are no longer available and status/trend have not been updated since 2013
  
  scen_year <- layers$data$scenario_year
  
  liv_fis_qual <-
    AlignDataYears(layer_nm = "liv_fis_qual", layers_obj = layers) %>%
    select(year = scenario_year, region_id = rgn_id, quality)
  
  liv_mar_qual <-
    AlignDataYears(layer_nm = "liv_mar_qual", layers_obj = layers) %>%
    select(year = scenario_year, region_id = rgn_id, quality)
  
  liv_tr_qual <-
    AlignDataYears(layer_nm = "liv_tr_qual", layers_obj = layers) %>%
    select(year = scenario_year, region_id = rgn_id, quality)
  
  labor_force <-
    AlignDataYears(layer_nm = "liv_labor_force", layers_obj = layers) %>%
    select(year = scenario_year, region_id = rgn_id, labor_force)
  
  liv_fis_quant <-
    AlignDataYears(layer_nm = "liv_fis_quant", layers_obj = layers) %>%
    select(year = scenario_year, region_id = rgn_id, quantity)
  
  liv_mar_quant <-
    AlignDataYears(layer_nm = "liv_mar_quant", layers_obj = layers) %>%
    select(year = scenario_year, region_id = rgn_id, quantity)
    
  liv_tr_quant <- 
    AlignDataYears(layer_nm = "liv_tr_quant", layers_obj = layers) %>%
    select(year = scenario_year, region_id = rgn_id, quantity)
  
  # Combine fis
  liv_fis <- liv_fis_quant %>%
    left_join(labor_force, by = c("year", "region_id")) %>%
    mutate(prop = quantity/labor_force) %>%
    select(year, region_id, prop) %>%
    full_join(liv_fis_qual, by = c("year", "region_id")) %>%
    mutate(liv = prop * quality) %>%
    filter(!is.na(prop)) %>%
    filter(!is.na(quality)) %>%
    group_by(region_id) %>%
    mutate(max_liv = if (any(year %in% 2016:2020)) {
        max(ifelse(year %in% 2016:2020, liv, NA), na.rm = TRUE)
      } else {
        NA_real_
      }) %>%
    mutate(liv_rescaled = liv/max_liv) %>%
    mutate(liv_rescaled = ifelse(liv_rescaled > 1, 1, liv_rescaled)) %>%
    select(year, region_id, liv, liv_rescaled) %>%
    mutate(sector = "fis")
  
  # Combine mar
  liv_mar <- liv_mar_quant %>%
    left_join(labor_force, by = c("year", "region_id")) %>%
    mutate(prop = quantity/labor_force) %>%
    select(year, region_id, prop) %>%
    full_join(liv_fis_qual, by = c("year", "region_id")) %>%
    mutate(liv = prop * quality) %>%
    filter(!is.na(prop)) %>%
    filter(!is.na(quality)) %>%
    group_by(region_id) %>%
    mutate(max_liv = if (any(year %in% 2016:2020)) {
      max(ifelse(year %in% 2016:2020, liv, NA), na.rm = TRUE)
    } else {
      NA_real_
    }) %>%
    mutate(liv_rescaled = liv/max_liv) %>%
    mutate(liv_rescaled = ifelse(liv_rescaled > 1, 1, liv_rescaled)) %>%
    select(year, region_id, liv, liv_rescaled) %>%
    mutate(sector = "mar")
  
  # Combine tr
  liv_tr <- liv_tr_quant %>%
    left_join(labor_force, by = c("year", "region_id")) %>%
    mutate(prop = quantity/labor_force) %>%
    select(year, region_id, prop) %>%
    full_join(liv_fis_qual, by = c("year", "region_id")) %>%
    mutate(liv = prop * quality) %>%
    filter(!is.na(prop)) %>%
    filter(!is.na(quality)) %>%
    group_by(region_id) %>%
    mutate(max_liv = if (any(year %in% 2016:2020)) {
      max(ifelse(year %in% 2016:2020, liv, NA), na.rm = TRUE)
    } else {
      NA_real_
    }) %>%
    mutate(liv_rescaled = liv/max_liv) %>%
    mutate(liv_rescaled = ifelse(liv_rescaled > 1, 1, liv_rescaled)) %>%
    select(year, region_id, liv, liv_rescaled) %>%
    mutate(sector = "tr")
  
 liv <- rbind(liv_fis, liv_mar, liv_tr) %>%
   group_by(region_id, year) %>%
   summarise(status = weighted.mean(liv_rescaled, liv)) %>%
   ungroup() 
 
 # Status
 status_liv <- liv %>%
   dplyr::mutate(goal = "LIV") %>%
   dplyr::filter(year == scen_year) %>%
   dplyr::mutate(dimension = 'status') %>%
   dplyr::select(region_id, status, dimension, goal) %>%
   mutate(score = round(status, 4)* 100) %>%
   select(-status)
  
  # Trend  
 trend_years <- (scen_year - 4):(scen_year)
 
 trend_liv <-
   CalculateTrend(status_data = liv, trend_years = trend_years) %>%
   mutate(goal = "LIV")
  
  scores <- rbind(status_liv, trend_liv) %>%
    dplyr::select(region_id, goal, dimension, score)
  
  return(scores)
}


ECO <- function(layers) {

  # NOTE: scripts and related files for calculating these subgoals is located: 
  # eez/archive
  # These data are no longer available and status/trend have not been updated since 2013
  
  scen_year <- layers$data$scenario_year
  
  ## status data
  status_eco <-
    AlignDataYears(layer_nm = "eco_status", layers_obj = layers) %>%
    dplyr::select(-layer_name, -eco_status_year) %>%
    dplyr::mutate(goal = "ECO") %>%
    dplyr::filter(scenario_year == scen_year) %>%
    dplyr::select(region_id = rgn_id, goal, score = status) %>%
    dplyr::mutate(dimension = 'status')
  
# trend data  
  trend_eco <-
    AlignDataYears(layer_nm = "eco_trend", layers_obj = layers) %>%
    dplyr::select(-layer_name, -eco_trend_year) %>%
    dplyr::mutate(goal = "ECO") %>%
    dplyr::filter(scenario_year == scen_year) %>%
    dplyr::select(region_id = rgn_id, goal, score = trend) %>%
    dplyr::mutate(dimension = 'trend')
  
  
    scores <- rbind(status_eco, trend_eco) %>%
    dplyr::select(region_id, goal, dimension, score)

  return(scores)
}

LE <- function(scores, layers) {
  
  s <- scores %>%
    dplyr::filter(goal %in% c('LIV', 'ECO'),
           dimension %in% c('status', 'trend', 'future', 'score')) %>%
    dplyr::group_by(region_id, dimension) %>%
    dplyr::summarize(score = mean(score, na.rm = TRUE)) %>%
    dplyr::ungroup() %>%
    dplyr::arrange(region_id) %>%
    dplyr::mutate(goal = "LE") %>%
    dplyr::select(region_id, goal, dimension, score) %>%
    data.frame()
  
  # return all scores
  return(rbind(scores, s))

}

ICO <- function(layers) {
  scen_year <- layers$data$scenario_year
  
  rk <-
    AlignDataYears(layer_nm = "ico_spp_iucn_status", layers_obj = layers) %>%
    dplyr::select(
      region_id = rgn_id,
      sciname,
      iucn_sid,
      iucn_cat = category,
      scenario_year,
      eval_yr,
      ico_spp_iucn_status_year
    ) %>%
    dplyr::mutate(iucn_cat = as.character(iucn_cat)) %>% 
    dplyr::group_by(region_id, iucn_sid) %>% 
    dplyr::mutate(sample_n = length(na.omit(unique(eval_yr[eval_yr > scen_year-19])))) %>% 
    dplyr::ungroup() %>% 
    dplyr::group_by(sciname, region_id) %>% 
    dplyr::mutate(sample_n = min(sample_n)) %>% 
    dplyr::ungroup()
  
  # lookup for weights status
  #  LC <- "LOWER RISK/LEAST CONCERN (LR/LC)"
  #  NT <- "LOWER RISK/NEAR THREATENED (LR/NT)"
  #  T  <- "THREATENED (T)" treat as "EN"
  #  VU <- "VULNERABLE (V)"
  #  EN <- "ENDANGERED (E)"
  #  LR/CD <- "LOWER RISK/CONSERVATION DEPENDENT (LR/CD)" treat as between VU and NT
  #  CR <- "VERY RARE AND BELIEVED TO BE DECREASING IN NUMBERS"
  #  DD <- "INSUFFICIENTLY KNOWN (K)"
  #  DD <- "INDETERMINATE (I)"
  #  DD <- "STATUS INADEQUATELY KNOWN-SURVEY REQUIRED OR DATA SOUGHT"
  
  w.risk_category <-
    data.frame(
      iucn_cat = c('LC', 'NT', 'CD', 'VU', 'EN', 'CR', 'EX', 'DD'),
      risk_score = c(0,  0.2,  0.3,  0.4,  0.6,  0.8,  1, NA)
    ) %>%
    dplyr::mutate(status_score = 1 - risk_score) %>%
    dplyr::mutate(iucn_cat = as.character(iucn_cat))
  
  ####### status
  # STEP 1: take mean of subpopulation scores
  r.status_spp <- rk %>%
    dplyr::left_join(w.risk_category, by = 'iucn_cat') %>%
    dplyr::group_by(region_id, sciname, scenario_year, ico_spp_iucn_status_year) %>%
    dplyr::summarize(spp_mean = mean(status_score, na.rm = TRUE)) %>%
    dplyr::ungroup()
  
  # STEP 2: take mean of populations within regions
  r.status <- r.status_spp %>%
    dplyr::group_by(region_id, scenario_year, ico_spp_iucn_status_year) %>%
    dplyr::summarize(status = mean(spp_mean, na.rm = TRUE)) %>%
    dplyr::ungroup()
  
  ####### status
  status <- r.status %>%
    filter(scenario_year == scen_year) %>%
    mutate(score = status * 100) %>%
    mutate(dimension = "status") %>%
    select(region_id, score, dimension)
  
  ####### trend
  trend_years <- (scen_year - 19):(scen_year)
  
  # trend calculated with status filtered for species with 2+ iucn evaluations in trend_years
  r.status_filtered <- rk %>% 
    dplyr::filter(sample_n >= 2) %>% 
    dplyr::left_join(w.risk_category, by = 'iucn_cat') %>%
    dplyr::group_by(region_id, sciname, scenario_year, ico_spp_iucn_status_year) %>%
    dplyr::summarize(spp_mean = mean(status_score, na.rm = TRUE)) %>%
    dplyr::ungroup() %>%
    dplyr::group_by(region_id, scenario_year, ico_spp_iucn_status_year) %>%
    dplyr::summarize(status = mean(spp_mean, na.rm = TRUE)) %>%
    dplyr::ungroup()
  
  trend <-
    CalculateTrend(status_data = r.status_filtered, trend_years = trend_years)
  
  
  ## Reference Point Accounting
  WriteRefPoint(goal = "ICO",
                method = "scaled IUCN risk categories",
                ref_pt = NA)
  ## Reference Point End  
  
  # return scores
  scores <-  rbind(status, trend) %>%
    dplyr::mutate('goal' = 'ICO') %>%
    dplyr::select(goal, dimension, region_id, score) %>%
    data.frame()
  
  ## Gapfill Oecussi Ambeno (rgn 237) with East Timor (rgn 231) data
  ## Oecussi Ambeno is an enclave within East Timor, so the data should be very similar
  go <- dplyr::filter(scores, region_id == 231) %>%
    dplyr::mutate(region_id = 237)
  scores <- rbind(scores, go)
  
  
  ## gapfill missing regions with average scores/trends of regions that share same UN geopolitical region
  un_regions <- georegions %>%
    dplyr::select(region_id = rgn_id, r2)
  
  # ID missing regions:
  regions <- SelectLayersData(layers, layers = c('rgn_global')) %>%
    dplyr::select(region_id = id_num)
  regions_NA <- setdiff(regions$region_id, scores$region_id)
  
  scores_NA <- data.frame(
    goal = "ICO",
    dimension = rep(c("status", "trend"),
                    each = length(regions_NA)),
    region_id = regions_NA,
    score = NA
  )
  
  scores <- scores %>%
    rbind(scores_NA) %>%
    dplyr::mutate(region_id = as.numeric(region_id)) %>%
    dplyr::left_join(un_regions, by = "region_id") %>%
    dplyr::group_by(dimension, r2) %>%
    dplyr::mutate(score_gf = mean(score, na.rm = TRUE)) %>%
    dplyr::arrange(dimension, region_id) %>%
    data.frame()
  
  # save gapfilling records
  scores_gf <- scores %>%
    dplyr::mutate(gapfilled = ifelse(is.na(score) &
                                !is.na(score_gf), "1", "0")) %>%
    dplyr::mutate(method = ifelse(
      is.na(score) &
        !is.na(score_gf),
      "UN geopolitical avg. (r2)",
      NA
    )) %>%
    dplyr::select(goal, dimension, region_id, gapfilled, method)
  write.csv(scores_gf, here("eez/temp/ICO_status_trend_gf.csv"), row.names = FALSE)
  
  scores <- scores %>%
    dplyr::mutate(score2 = ifelse(is.na(score), score_gf, score)) %>%
    dplyr::select(goal, dimension, region_id, score = score2) %>%
    data.frame()
  
  return(scores)
  
}

LSP <- function(layers) {
  scen_year <- layers$data$scenario_year
  
  ref_pct_cmpa <- 30
  ref_pct_cp <- 30
  
  # select data
  total_area <-
    rbind(layers$data$rgn_area_inland1km,
          layers$data$rgn_area_offshore3nm) %>% #total offshore/inland areas
    dplyr::select(region_id = rgn_id, area, layer) %>%
    tidyr::spread(layer, area) %>%
    dplyr::select(region_id,
           area_inland1km = rgn_area_inland1km,
           area_offshore3nm = rgn_area_offshore3nm)
  
  
  offshore <-
    AlignDataYears(layer_nm = "lsp_prot_area_offshore3nm", layers_obj = layers) %>%
    dplyr::select(region_id = rgn_id,
           year = scenario_year,
           cmpa = a_prot_3nm)
  inland <-
    AlignDataYears(layer_nm = "lsp_prot_area_inland1km", layers_obj = layers) %>%
    dplyr::select(region_id = rgn_id,
           year = scenario_year,
           cp = a_prot_1km)
  
  lsp_data <- full_join(offshore, inland, by = c("region_id", "year"))
  
  # fill in time series for all regions
  lsp_data_expand <-
    expand.grid(region_id = unique(lsp_data$region_id),
                year = unique(lsp_data$year)) %>%
    dplyr::left_join(lsp_data, by = c('region_id', 'year')) %>%
    dplyr::arrange(region_id, year) %>%
    dplyr::mutate(cp = ifelse(is.na(cp), 0, cp),
           cmpa = ifelse(is.na(cmpa), 0, cmpa)) %>%
    dplyr::mutate(pa     = cp + cmpa)
  
  
  # get percent of total area that is protected for inland1km (cp) and offshore3nm (cmpa) per year
  # and calculate status score
  status_data <- lsp_data_expand %>%
    dplyr::full_join(total_area, by = "region_id") %>%
    dplyr::mutate(
      pct_cp    = pmin(cp   / area_inland1km   * 100, 100),
      pct_cmpa  = pmin(cmpa / area_offshore3nm * 100, 100),
      status    = (pmin(pct_cp / ref_pct_cp, 1) + pmin(pct_cmpa / ref_pct_cmpa, 1)) / 2
    ) %>%
    dplyr::filter(!is.na(status))
  
  # extract status based on specified year
  
  r.status <- status_data %>%
    dplyr::filter(year == scen_year) %>%
    dplyr::mutate(score = status * 100) %>%
    dplyr::select(region_id, score) %>%
    dplyr::mutate(dimension = "status")
  
  # calculate trend
  
  trend_years <- (scen_year - 4):(scen_year)
  
  r.trend <-
    CalculateTrend(status_data = status_data, trend_years = trend_years)
  
  
  ## Reference Point Accounting
  WriteRefPoint(
    goal = "LSP",
    method = paste0(
      ref_pct_cmpa,
      "% marine protected area; ",
      ref_pct_cp,
      "% coastal protected area"
    ),
    ref_pt = "varies by area of region's eez and 1 km inland"
  )
  ## Reference Point End  
  
  # return scores
  scores <- dplyr::bind_rows(r.status, r.trend) %>%
    mutate(goal = "LSP")
  return(scores[, c('region_id', 'goal', 'dimension', 'score')])
}

SP <- function(scores) {
  ## to calculate the four SP dimesions, average those dimensions for ICO and LSP
  s <- scores %>%
    dplyr::filter(goal %in% c('ICO', 'LSP'),
           dimension %in% c('status', 'trend', 'future', 'score')) %>%
    dplyr::group_by(region_id, dimension) %>%
    dplyr::summarize(score = mean(score, na.rm = TRUE)) %>%
    dplyr::ungroup() %>%
    dplyr::arrange(region_id) %>%
    dplyr::mutate(goal = "SP") %>%
    dplyr::select(region_id, goal, dimension, score) %>%
    data.frame()
  
  # return all scores
  return(rbind(scores, s))
}


CW <- function(layers) {
  
  scen_year <- layers$data$scenario_year
  
  ### function to calculate geometric mean:
  geometric.mean2 <- function (x, na.rm = TRUE) {
    if (is.null(nrow(x))) {
      exp(mean(log(x), na.rm = TRUE))
    }
    else {
      exp(apply(log(x), 2, mean, na.rm = na.rm))
    }
  }
  
  
  # layers
  trend_lyrs <-
    c('cw_chemical_trend',
      'cw_nutrient_trend',
      'cw_trash_trend',
      'cw_pathogen_trend')
  prs_lyrs <-
    c('po_pathogens',
      'po_nutrients_3nm',
      'po_chemicals_3nm',
      'po_trash')
  
  # get data together:
  prs_data <- AlignManyDataYears(prs_lyrs) %>%
    dplyr::filter(scenario_year == scen_year) %>%
    dplyr::select(region_id = rgn_id, value = pressure_score)
  
  d_pressures <- prs_data %>%
    dplyr::mutate(pressure = 1 - value) %>%  # invert pressure
    dplyr::mutate(pressure = ifelse(pressure == 0 , pressure + 0.01, pressure)) %>% # add small modifier to zeros to 
    dplyr::group_by(region_id) %>%                                                  # prevent zeros with geometric mean
    dplyr::summarize(score = geometric.mean2(pressure, na.rm = TRUE)) %>% # take geometric mean
    dplyr::mutate(score = score * 100) %>%
    dplyr::mutate(dimension = "status") %>%
    dplyr::ungroup()
  
  
  # get trend data together:
  trend_data <- AlignManyDataYears(trend_lyrs) %>%
    dplyr::filter(scenario_year == scen_year) %>%
    dplyr::select(region_id = rgn_id, value = trend)
  
  d_trends <- trend_data %>%
    dplyr::mutate(trend = -1 * value)  %>%  # invert trends
    dplyr::group_by(region_id) %>%
    dplyr::summarize(score = mean(trend, na.rm = TRUE)) %>%
    dplyr::mutate(dimension = "trend") %>%
    dplyr::ungroup()
  
  
  # return scores
  scores <- rbind(d_pressures, d_trends) %>%
    dplyr::mutate(goal = "CW") %>%
    dplyr::select(region_id, goal, dimension, score) %>%
    data.frame()
  
  ## Reference Point Accounting
  WriteRefPoint(goal   = "CW",
                method = "spatial: pressures scaled from 0-1 at raster level",
                ref_pt = NA)
  ## Reference Point End  
    
  return(scores)
}


HAB <- function(layers) {
  scen_year <- layers$data$scenario_year
  
  extent_lyrs <-
    c(
      'hab_mangrove_extent',
      'hab_seagrass_extent',
      'hab_saltmarsh_extent',
      'hab_coral_extent',
      'hab_seaice_extent',
      'hab_softbottom_extent',
      'hab_kelp_extent',
      'hab_tidal_flat_extent',
      'hab_beaches_extent'
    )
  health_lyrs <-
    c(
      'hab_mangrove_health',
      'hab_seagrass_health',
      'hab_saltmarsh_health',
      'hab_coral_health',
      'hab_seaice_health',
      'hab_softbottom_health',
      'hab_kelp_health',
      'hab_tidal_flat_health',
      'hab_beaches_health'
    )
  trend_lyrs <-
    c(
      'hab_mangrove_trend',
      'hab_seagrass_trend',
      'hab_saltmarsh_trend',
      'hab_coral_trend',
      'hab_seaice_trend',
      'hab_softbottom_trend',
      'hab_kelp_trend',
      'hab_tidal_flat_trend',
      'hab_beaches_trend'
    )
  
  # get data together:
  extent <- AlignManyDataYears(extent_lyrs) %>%
    dplyr::filter(scenario_year == scen_year) %>%
    dplyr::select(region_id = rgn_id, habitat, extent = km2) %>%
    dplyr::mutate(habitat = as.character(habitat))
  
  health <- AlignManyDataYears(health_lyrs) %>%
    dplyr::filter(scenario_year == scen_year) %>%
    dplyr::select(region_id = rgn_id, habitat, health) %>%
    dplyr::mutate(habitat = as.character(habitat))
  
  trend <- AlignManyDataYears(trend_lyrs) %>%
    dplyr::filter(scenario_year == scen_year) %>%
    dplyr::select(region_id = rgn_id, habitat, trend) %>%
    dplyr::mutate(habitat = as.character(habitat))
  
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
  
  if (sum(d$w %in% 1 & is.na(d$trend)) > 0) {
    warning(
      "Some regions/habitats have extent data, but no trend data.  Consider estimating these values."
    )
  }
  
  if (sum(d$w %in% 1 & is.na(d$health)) > 0) {
    warning(
      "Some regions/habitats have extent data, but no health data.  Consider estimating these values."
    )
  }
  
  
  ## calculate scores
  status <- d %>%
    dplyr::group_by(region_id) %>%
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
    dplyr::select(region_id, goal, dimension, score)
  
  ## Reference Point Accounting
  WriteRefPoint(goal = "HAB",
                method = "Health/condition variable based on current vs. historic extent",
                ref_pt = "varies for each region/habitat")
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
  
  write.csv(weights,
            sprintf(here("eez/temp/element_wts_hab_pres_abs_%s.csv"), scen_year),
            row.names = FALSE)
  
  layers$data$element_wts_hab_pres_abs <- weights
  
  
  # return scores
  return(scores_HAB)
}


SPP <- function(layers) {

  scen_year <- layers$data$scenario_year
  
status <- AlignDataYears(layer_nm = "spp_status", layers_obj = layers) %>%
   dplyr::filter(scenario_year == scen_year) %>%
    dplyr::select(region_id = rgn_id,
                  score) %>%
  dplyr::mutate(dimension = "status") %>%
  dplyr::mutate(score = score * 100)
  
trend <- layers$data$spp_trend %>%
  dplyr::select(region_id = rgn_id,
                score) %>%
  dplyr::mutate(dimension = "trend")

scores <- rbind(status, trend) %>%
    dplyr::mutate(goal = 'SPP') %>%
    dplyr::select(region_id, goal, dimension, score)
  
  ## Reference Point Accounting
  WriteRefPoint(goal = "SPP",
                method = "Average of IUCN risk categories, scaled to historic extinction",
                ref_pt = NA)
  ## Reference Point End  
  
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

PreGlobalScores <- function(layers, conf, scores) {
  # get regions
  name_region_labels <- conf$config$layer_region_labels
  rgns <- layers$data[[name_region_labels]] %>%
    dplyr::select(id_num = rgn_id, val_chr = label)
  
  # limit to just desired regions and global (region_id==0)
  scores <- subset(scores, region_id %in% c(rgns[, 'id_num'], 0))
  
  # apply NA to Antarctica
  id_ant <- subset(rgns, val_chr == 'Antarctica', id_num, drop = TRUE)
  scores[scores$region_id == id_ant, 'score'] = NA
  
  return(scores)
}

FinalizeScores <- function(layers, conf, scores) {
  # get regions
  name_region_labels <- conf$config$layer_region_labels
  rgns <- layers$data[[name_region_labels]] %>%
    dplyr::select(id_num = rgn_id, val_chr = label)
  
  
  # add NAs to missing combos (region_id, goal, dimension)
  d <- expand.grid(list(
    score_NA  = NA,
    region_id = c(rgns[, 'id_num'], 0),
    dimension = c(
      'pressures',
      'resilience',
      'status',
      'trend',
      'future',
      'score'
    ),
    goal      = c(conf$goals$goal, 'Index')
  ),
  stringsAsFactors = FALSE)
  head(d)
  d <- subset(d,!(
    dimension %in% c('pressures', 'resilience', 'trend') &
      region_id == 0
  ) &
    !(
      dimension %in% c('pressures', 'resilience', 'trend', 'status') &
        goal == 'Index'
    ))
  scores <-
    merge(scores, d, all = TRUE)[, c('goal', 'dimension', 'region_id', 'score')]
  
  # order
  scores <- dplyr::arrange(scores, goal, dimension, region_id)
  
  # round scores
  scores$score <- round(scores$score, 2)
  
  return(scores)
}
