# params: 
# 1: is always the output folder
# 2: species scientific name
# 3: 3-letter country code (ex: CAN for Canada, COL for Colombia)


# Packages requiered -----------

packages <- c("rgbif", "raster", 'dismo', "ENMeval", "dplyr", "CoordinateCleaner", "adehabitatHR", "rgeos", "sf", "terra", "sp",
              "virtualspecies")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]

if(length(new.packages)) install.packages(new.packages)

# WorldClimTiles not in CRAN
remotes::install_github("kapitzas/WorldClimTiles")

# 0. Receive args ----------
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
print(paste0("outputFolder ", outputFolder))
setwd(outputFolder)

species <- "Aotus lemurinus"# args[2]
countryCode <- "COL"
print(paste0("species ", species))
countryCode <- args[3]
print(paste0("countryCode  ", countryCode))


# REMOPVING COLLINEARITY MODULE 
source(file.path(Sys.getenv("SCRIPT_LOCATION"), "removeCollinearity.R"))

# CLEANING DATA MODULE 
source(file.path(Sys.getenv("SCRIPT_LOCATION"), "cleanOccurrences.R"))



run_sdm <- function(species, country_code, min_obs = 20, targetRes = 0.08333333, do_cleaning = TRUE, uncertainty = FALSE) {
  
  ######### START PIPELINE ######################
  
  library("rgbif")
  library("dplyr")
  library("raster")
  library("adehabitatHR")
  library("sf")
  library("sp")
  library("rgeos")
  library("CoordinateCleaner")
  library("WorldClimTiles")
  library('dismo')
  library('ENMeval')
  library('virtualspecies')
  
  # Projections
  # Geographic
  wgs84 <- "+proj=longlat +datum=WGS84 +no_defs" 
  # Projected (from https://spatialreference.org/ref/sr-org/62/) to preserve area (Global Albers Equal Area)
  aea <- "+proj=aea +lat_1=29.83333333333334 +lat_2=45.83333333333334 +lat_0=37.5 +lon_0=-96 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs "
  
  
  
  # 1. Observations ---------
  
  # TODO: Move this to another module, load it here
  # Loading data from GBIF (https://www.gbif.org/)
  
  print("Loading species observations.")
  # TODO: Bound to region of interest
  Obs_gbif_data <- rgbif::occ_data(scientificName = species, hasCoordinate = TRUE, limit=10000)
  
  if (is.null(Obs_gbif_data$data)) {
    stop(sprintf('No observations found for the species %s', species))
  } else if (!is.null(Obs_gbif_data$data) && nrow(Obs_gbif_data$data) < min_obs) {
    stop(sprintf('Minimum number of observations (%s) not reached.', min_obs))
  } else {
    sprintf('%s observations loaded.', nrow(Obs_gbif_data$data))
  }
  
  
  #Creating spatial feature (points)
  
  Obs_gbif_data_sp <- data.frame(cbind(Obs_gbif_data$data$decimalLongitude, Obs_gbif_data$data$decimalLatitude))%>%
    sp::SpatialPoints(proj4string=CRS(wgs84))
  
  
  # 2. Predictors ------------
  
  ## THIS IS THE PART WHERE GUILLAUME IS GOING TO RETRIEVE DATA PREDICTORS FROM PLANETARY COMPUTER (CRETAE THE CUBE)
  ### AND OTHER SOURCES, WE INCLUDED HERE BIOCLIM FROM WORLDCLIM, HOWEVER WE CAN TRY CHELSA...
  
  
  # 2.1 Bioclim  -------
  
  # Creating box extent to download predictors
  
  
  box_extent_analysis <- mcp(Obs_gbif_data_sp, percent = 100)%>%
    st_as_sf()%>%
    st_transform(crs=aea)
  
  # Buffering box extent
  
  box_extent_analysis_bf <-  st_buffer(box_extent_analysis, dist =  100000)
  
  # To save time we are going to use Country box OTHERWISE USE box_extent_analysis_bf instead of Colombia_boundary
  country_boundary <- raster::getData("GADM", country = country_code, level = 0) #Downloading COLOMBIA"s boundaries
  
  box_extent_bioclim <- WorldClimTiles::tile_name(country_boundary, "worldclim") # determine which WorldClim tiles your study area intersects with.
  
  subDir <- file.path(".", "bioclim_t")
  dir.create(subDir, showWarnings = FALSE) 
  
  clim_tiles <- tile_get(box_extent_bioclim, name =  "worldclim", var="bio", path = subDir) # for 0.5 arcmin worldclim tiles of 
  rawPredictors <- tile_merge(clim_tiles)
  
  # Change the resolutuion (upscale if fact > 1, downscale if fact <1)
  
  fact <- targetRes/res(rawPredictors)[1]
  
  if (fact > 1) {
    rawPredictors <- raster::aggregate(rawPredictors, fact = fact, fun = mean)
    sprintf("Predictor layers aggregated to resolution %s ", targetRes)
  } else if (fact < 1) {
    
    rawPredictors <- raster::disaggregate(rawPredictors, fact = fact, fun = mean)
    sprintf("Predictor layers disaggregated to resolution %s ", targetRes)
  } else {
    
  }
  
  # Remove collinearity
  
  nonCollinearPredictors <- removeCollinearity(rawPredictors,
                                     method = "vif.step",
                                     sample = TRUE, 
                                     cutoff.vif = 10,
                                     export = F)
  
  
  # 2.2 From Planetary Computer -----------
  
  # Let's include a list of predictors
  # from the PC Catalog (We need to add some ID from the PC CATALOG  to guide Violet in her search)
  #  Land cover
  #  Topography (elevation, slope, aspect)
  # Others ??? type of soil
  
  #2.3 Stacking variables using same spatial resolution and extent.
  
  
  # 3. Data cleaning ------------
  
  # Remove collinearity in predictors variables
  
  # nonCollinearPredictors <- selectVariables(rawPredictors, sample = TRUE, cutoff = 0.7)
  
  # Clean observations
  
  
  if (do_cleaning) {
    
    Obs_gbif_data <- cleanOccurrences(x = Obs_gbif_data$data,
                                      predictors = nonCollinearPredictors,
                                      unique_id = "key",
                                       lon = "decimalLongitude", 
                                       lat = "decimalLatitude", 
                                      species_col = "scientificName",
                                       # all tests by default
                                       # see https://cran.r-project.org/web/packages/CoordinateCleaner/index.html for details
                                       # remove the seas test for marine species
                                       tests = c( "equal",
                                                  "zeros", 
                                                  "duplicates", 
                                                  "capitals", 
                                                  "centroids",
                                                  "seas", 
                                                  "same_pixel",
                                                  "gbif", 
                                                  "institutions"
                                       ), 
                                       dir = getwd(), # directory to store cleaning report, only uised if report =  TRUE
                                       additions = c("eventDate"), # use for filtering duplicates (same coordinates and eventDate)
                                       value = "clean", # problematic occurrences removed
                                       verbose = TRUE,
                                       report = TRUE) # if TRUE, cleaning report will be saved in the dir directory
    
  } else {
    
    Obs_gbif_data <- Obs_gbif_data$data 
    
  }
  
  
  if (class(Obs_gbif_data) == "data.frame" && nrow(Obs_gbif_data) > 0) {
  
  # 3. Model fitting ------
  
  # Rename observations columns
  occs <- dplyr::select(Obs_gbif_data, decimalLongitude, decimalLatitude) %>%
    dplyr::rename(longitude = decimalLongitude,  latitude =  decimalLatitude)
  
  
  # Pseudo-absences
  rNA <- table(is.na(nonCollinearPredictors[[1]][]))
  n <- min(rNA[["FALSE"]], n) # if not enough non NA cells in the raster, reduce the number of background points
  message(sprintf("Selecting %i background points", n))
  bg_points <- dismo::randomPoints(nonCollinearPredictors[[1]], n = n) %>% as.data.frame()
  colnames(bg_points) <- colnames(occs)
  
  
  # Model (using Maxent in ENMeval) basic parameters
  model_species <- ENMeval::ENMevaluate(occs = occs, envs = nonCollinearPredictors , bg = bg_points, 
                                        algorithm = 'maxent.jar',
                                        partitions = 'block',
                                        tune.args = list(fc = "L", rm = 1),
                                        parallel =  TRUE,
                                        updateProgress = TRUE,
                                        parallelType = "doParallel"
  )
  
  # 4. Predictions -------
  
  model_species_prediction <- ENMeval::eval.predictions(model_species)
  terra::writeRaster(terra::rast(model_species_prediction), paste0(getwd(), "/prediction.tif"),
                     overwrite=TRUE)
  
  #############END PIPELINE ####################################
}

}
run_sdm(species, countryCode)


