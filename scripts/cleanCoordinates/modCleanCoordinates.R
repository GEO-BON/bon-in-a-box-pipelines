

## Install required packages
packages <- c("terra", "rjson", "raster", "dplyr", "CoordinateCleaner")
packages_github <- c("gdalcubes", "stacatalogue")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]

if(length(new.packages)) install.packages(new.packages)

library("devtools")
if (!"stacatalogue" %in% installed.packages()[,"Package"]) devtools::install_github("ReseauBiodiversiteQuebec/stac-catalogue")
if (!"gdalcubes" %in% installed.packages()[,"Package"]) devtools::install_github("appelmar/gdalcubes_R")

## Load required packages
library("terra")
library("rjson")
library("raster")
library("CoordinateCleaner")
library("dplyr")
library("gdalcubes")
library("stacatalogue")


## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "cleanCoordinates/funcCleanCoordinates.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "loadPredictors/funcLoadPredictors.R", sep = "/"))

## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

presence <- read.table(file = input$presence, sep = '\t', header = TRUE) 
presence <- dplyr::rename(presence, scientific_name = scientificName)

presence <- create_projection(presence, lon = "decimalLongitude", lat = "decimalLatitude", 
proj_from = "+proj=longlat +datum=WGS84", proj_to = input$proj_to, new_lon = "lon", new_lat = "lat") 

bbox <- points_to_bbox(dplyr::select(presence, lon, lat), proj_from = input$proj_to)

layers <- input$layers

#layers <- c("bio1", "bio2", "bio8")
predictors_nc <- load_predictors(source = "from_cube",
                            cube_args = list(stac_path = "http://io.biodiversite-quebec.ca/stac/",
            limit = 5000, 
            collections = c("chelsa-clim"),     
            t0 = "1981-01-01",
            t1 = "1981-01-01",
            spatial.res = input$spatial_res, # in meters
            temporal.res = "P1Y",
            aggregation = "mean",
            resampling = "near"),
                          
                          predictors_dir = NULL,
                           subset_layers = layers,
                           remove_collinear = F,
                           method = "vif.cor",
                           method_cor_vif = "pearson",
                           proj = input$proj_to,
                           bbox = bbox,
                           sample = TRUE,
                           nb_points = 50000,
                           cutoff_cor = 0.7,
                           cutoff_vif = 3,
                           export = T,
                           ouput_dir = getwd(),
                           as_list = F)

  clean_presence <- clean_coordinates(
      x = presence,
      predictors = predictors_nc,
      spatial_res = input$spatial_res,
      species_name = species,
      srs = input$proj_to,
      unique_id = "id",
      lon = "lon",
      lat = "lat",
      species_col = "scientific_name",
      tests = input$tests,
      threshold_env = 0.8,
       report = F,
   value = "clean"
    )
    clean_presence <-  clean_presence %>% # summary = TRUE means the observations was identified as an outlier at least once during the cleaning procedure
      dplyr::select(id, scientific_name, lon, lat)



output_clean_presence <- file.path(outputFolder, "clean_presence.tsv")

write.table(clean_presence, output_clean_presence, 
             append = F, row.names = F, col.names = T, sep = "\t")


  output <- list("n_observations" =  nrow(presence),
                 "n_clean" = nrow(clean_presence),
                  "clean_presence" = output_clean_presence
                  ) 
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))