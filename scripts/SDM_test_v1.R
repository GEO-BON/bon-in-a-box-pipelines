
######### START PIPELINE ######################

# Packages requiered -----------

packages <- c("rgbif", "raster", 'dismo', "ENMeval", "dplyr", "CoordinateCleaner", "adehabitatHR", "rgeos","sf")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]

if(length(new.packages)) install.packages(new.packages)

# WorldClimTiles not in CRAN
devtools::install_github("kapitzas/WorldClimTiles")

## 2nd option, install missing packages and load them (may be preferred)
# package.check <- lapply(
#   packages,
#   FUN = function(x) {
#     if (!require(x, character.only = TRUE)) {
#       install.packages(x, dependencies = TRUE)
#       library(x, character.only = TRUE)
#     }
#   }
# )


# 0. Settings ----------
setwd(Sys.getenv("OUTPUT_LOCATION"))

mainDir <- getwd()
subDir <- "GeoBON"
dir.create(file.path(mainDir, subDir), showWarnings = FALSE) #dir.create() does not crash if the directory already exists}
setwd(file.path(mainDir, subDir))


# CLEANING DATA MODULE 
source(file.path(Sys.getenv("SCRIPT_LOCATION"), "clean_occurrences.R"))

# Projections
 # Geographic
  wgs84 <- "+proj=longlat +datum=WGS84 +no_defs" 
 # Projected (from https://spatialreference.org/ref/sr-org/62/) to preserve area (Global Albers Equal Area)
  aea <- "+proj=aea +lat_1=29.83333333333334 +lat_2=45.83333333333334 +lat_0=37.5 +lon_0=-96 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs "



# 1. Observations ---------

library("rgbif")
library("dplyr")
myspecies <- c("Panthera onca")


# Loading data from GBIF (https://www.gbif.org/)
Obs_gbif_data <- occ_data(scientificName = myspecies, hasCoordinate = TRUE, limit=50000)

#Creating spatial feature (points)
library("raster")

Obs_gbif_data_sp <- data.frame(cbind(Obs_gbif_data$data$decimalLongitude, Obs_gbif_data$data$decimalLatitude))%>%
  sp::SpatialPoints(proj4string=CRS(wgs84))
  
# Creating box extent to download predictors
library("adehabitatHR")
library("sf")

box_extent_analysis <- mcp(Obs_gbif_data_sp, percent = 100)%>%
 st_as_sf()%>%
  st_transform(crs=aea)

# Buffering box extent
library("rgeos")
box_extent_analysis_bf <-  st_buffer(box_extent_analysis, dist =  100000)

  
# Cleaning occurrence
do_cleaning <- FALSE



if (do_cleaning) {
library("CoordinateCleaner")
Obs_gbif_data <- clean_occurrences(Obs_gbif_data$data,
                                 id = "key",
                                 lon = "decimalLongitude", 
                                 lat = "decimalLatitude", 
                                 # all tests by default
                                 # see https://cran.r-project.org/web/packages/CoordinateCleaner/index.html for details
                                 # remove the seas test for marine species
                                 tests = c( "equal",
                                            "zeros", 
                                            "duplicates", 
                                            "capitals", 
                                            "centroids",
                                            "seas", 
                                            "urban",
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

# 2. Predictors ------------

## THIS IS THE PART WHERE GUILLAUME IS GOING TO RETRIEVE DATA PREDICTORS FROM PLANETARY COMPUTER (CRETAE THE CUBE)
### AND OTHER SOURCES, WE INCLUDED HERE BIOCLIM FROM WORLDCLIM, HOWEVER WE CAN TRY CHELSA...


# 2.1 Bioclim  -------
library("WorldClimTiles")

# To save time we are going to use Country box OTHERWISE USE box_extent_analysis_bf instead of Colombia_boundary
Colombia_boundary <- getData("GADM", country = "COL", level = 0) #Downloading COLOMBIA"s boundaries

box_extent_bioclim <- tile_name(Colombia_boundary, "worldclim") # determine which WorldClim tiles your study area intersects with.

if(dir.exists("./bioclim_t")){
}else{
  out_sdm_mapsBIO <-   dir.create("./bioclim_t")}

clim_tiles <- tile_get(box_extent_bioclim, name =  "worldclim", var="bio", path = "./bioclim_t") # for 0.5 arcmin worldclim tiles of 
clim_tiles_merge <- tile_merge(clim_tiles)

# Agregagate (Let's try coarse resolution to speed up the process)
clim_tiles_merge_agg <- raster::aggregate(clim_tiles_merge, fact=10, fun=mean)


# 2.2 From Planetary Computer -----------

# Let's include a list of predictors
# from the PC Catalog (We need to add some ID from the PC CATALOG  to guide Violet in her search)
#  Land cover
#  Topography (elevation, slope, aspect)
# Others ??? type of soil

#2.3 Stacking variables using same spatial resolution and extent.

    

# 3. Model fitting ------

# Rename observations columns
occs <- dplyr::select(Obs_gbif_data, decimalLongitude, decimalLatitude) %>%
  dplyr::rename(longitude = decimalLongitude,  latitude =  decimalLatitude)


# Pseudo-absences
library('dismo')
bg_points <- dismo::randomPoints(clim_tiles_merge_agg$bio1, n = 5000) %>% as.data.frame()
colnames(bg_points) <- colnames(occs)


library('ENMeval')
# Model (using Maxent in ENMeval) basic parameters
model_species <- ENMeval::ENMevaluate(occs = occs, envs = clim_tiles_merge_agg , bg = bg_points, 
                                      algorithm = 'maxent.jar',
                                      partitions = 'block',
                                      tune.args = list(fc = "L", rm = 1),
                                      parallel =  TRUE,
                                      updateProgress = TRUE,
                                      parallelType = "doParallel"
)

# 4. Predictions -------

model_species_prediction <- eval.predictions(model_species)


# 5.  Model uncertainty ---------

# let's run 10 models and calculate the coefficient of variance (the only think will change is background points)

model_10 <- list()

for(i in 1:10){
  cat(paste0("Testing background points_model_", i), '\n')
  

  bg_points <- dismo::randomPoints(clim_tiles_merge_agg$bio1, n = 5000) %>% as.data.frame()
  colnames(bg_points) <- colnames(occs)
  
  model_10[[i]] <- ENMeval::ENMevaluate(occs = occs, envs = clim_tiles_merge_agg , bg = bg_points, 
                               algorithm = 'maxent.jar',
                               partitions = 'block',
                               tune.args = list(fc = "L", rm = 1),
                               parallel =  TRUE,
                               updateProgress = TRUE,
                               parallelType = "doParallel"
  )
  
}


model_10_predictions <- stack(lapply(model_10, eval.predictions))
uncertainty <- cv(model_10_predictions)


#############END PIPELINE ####################################

