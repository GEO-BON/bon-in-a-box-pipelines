# region data layers----
# a list of possible id fields used in datalayers (most will use rgn_id, but not always)
layers_id_fields    = c('rgn_id','cntry_key', 'fao_id', 'fao_saup_id', 'country_id','saup_id','fao_ohi_id') 

# the official list of regions (and corresponding names)
# (note: this is a .csv file in the layers folder)
layer_region_labels = 'rgn_global'   

# the official ocean areas of each region (used to weight each subregions contribution to the region score)
# (note: this is a .csv file in the layers folder)
layer_region_areas  = 'rgn_area'

# pressures & resilience matrices ----

# For goals with elements (e.g., for coastal protection: mangrove, saltmarsh, seagrass), these data layers describe how to weight the contribution of each goal element to calculate the final goal pressure and resilience dimensions.
# (note: these are .csv files in the layers folder)
resilience_element = list('NP'  = 'np_harvest_product_weight',
                          'CS'  = 'element_wts_cs_km2_x_storage',      # populated in CS() in functions.R
                          'CP'  = 'element_wts_cp_km2_x_protection',   # populated in CP() in functions.R
                          'HAB' = 'element_wts_hab_pres_abs')          # populated in HAB() in functions.R

pressures_element  = list('NP'  = 'np_harvest_product_weight',
                          'CS'  = 'element_wts_cs_km2_x_storage',      # populated in CS() in functions.R
                          'CP'  = 'element_wts_cp_km2_x_protection',   # populated in CS() in functions.R
                          'LIV' = 'le_sector_weight',
                          'ECO' = 'le_sector_weight',
                          'HAB' = 'element_wts_hab_pres_abs')          # populated in CS() in functions.R


# constants
# These are used in the Calculate functions in ohicore to calculate pressures/resilience/trend/likely future state
pressures_gamma = 0.5  # The relative importance of social vs. ecological pressures (pressure = gamma * ecological + (1-gamma) * social)
resilience_gamma = 0.5 # The relative importance of social vs. ecological resiliences (resilience = gamma * ecological + (1-gamma) * social)
goal_discount = 1.0    # Used to calculate likely future state
goal_beta = 0.67       # The relative importance of trend vs. pressure/resilience on likely future state; if goal_beta = 0.67, trend is twice as important as pressure/resilience.
default_trend = 0

# spatial configuration (used by shiny app and future ohicore mapping functions that use leaflet)
geojson = '../eez2015/spatial/rgn_offshore_gcs_mapshaper-simplify_x2_eez-only.geojson'

# extra descriptions not covered by goals.description or layers.description, used in ohigui
index_description = 'The overall Index represents the weighted average of all goal scores.'
dimension_descriptions = c('score' = 'This dimension is an average of the current status and likely future.',
                           'status' = 'This dimension represents the current value of a goal or sub-goal relative to its reference point.',
                           'future' = 'For this dimension, the likely future is calculated as the projected status in 5 years, informed by the current status, continued trend, inflected upwards by resilience and downwards by pressures.',
                           'trend' = 'This dimension represents the recent change in the value of the status. Unlike all other dimensions which range in value from 0 to 100, the trend ranges from -1 to 1, representing the steepest declines to increases respectively.',
                           'pressures' = 'This dimension represents the anthropogenic stressors that negatively affect the ability of a goal to be delivered to people. Pressures can affect either ecological or social (i.e. human) systems.',
                           'resilience' = 'This dimension represents the social, institutional, and ecological factors that positively affect the ability of a goal to be delivered to people.')
