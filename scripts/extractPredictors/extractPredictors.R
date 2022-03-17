## Environment variables available
# Script location can be used to access other scripts
print(Sys.getenv("SCRIPT_LOCATION"))

## Install required packages
packages <- c("gdalcubes", "rjson", "raster", "dplyr", "rstac", "tibble", "sp", "sf", "rgdal", "RCurl", "lubridate")

new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
## Load required packages
library("gdalcubes")
library("rjson")
library("raster")
library("dplyr")
library("rstac")
library("tibble")
library("sp")
library("sf")
library("RCurl")
options(timeout = max(60000000, getOption("timeout")))

## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")
setwd(outputFolder)

input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)



# Load functions
source("/scripts/extractPredictors/funcExtractPredictors.R")
source("/scripts/utils/utils.R")

obs <- read.table(file = input$obs, sep = '\t', header = TRUE) 

obs.proj <- dplyr::select(obs, decimalLongitude, decimalLatitude)

obs.coords.proj <-  create_projection(obs.proj, lon = "decimalLongitude", lat = "decimalLatitude", proj.from = input$srs.obs, proj.to = input$srs.cube,
  new.lon = "lon", new.lat = "lat")

cube <- 
  load_cube(stac_path = input$stac_path,
           limit = input$limit, 
           collections = c(input$collections), 
           use.obs = T,
           obs = obs.coords.proj,
           lon = "lon",
           lat = "lat",
           buffer.box = input$buffer.box,
           layers = input$layers,
           srs.cube = input$srs.cube,
           t0 = input$t0,
           t1 = input$t1,
           spatial.res = input$spatial.res,
           temporal.res = input$temporal.res) 



# DEPRECATED: older version of gdalcubes
#value.points <- query_points(cube, obs.proj$lon, obs.proj$lat, 
 # pt = rep(as.Date(input$t0), length(obs.proj$lon)), srs(cube)) %>% data.frame()
#obs <- bind_cols(obs,
 # value.points)

value.points <- extract_geom(cube, sf::st_as_sf(obs.coords.proj, coords = c("lon", "lat"),
                                                         crs = input$srs.cube)) 


extracted.values <- dplyr::bind_cols(
          dplyr::select(obs, scientificName) %>% rename(scientific_name = scientificName),
          dplyr::select(value.points, FID, time) %>% dplyr::rename(id = FID),
          data.frame(obs.coords.proj),
          dplyr::select(value.points, dplyr::all_of(input$layers))) 


obs.values <- file.path(outputFolder, "obs_values_out.tsv")
write.table(extracted.values, obs.values,
             append = F, row.names = F, col.names = T, sep = "\t")


  output <- list(
                  "obs.values" = obs.values
                  ) 
  jsonData <- toJSON(output, indent=2)
  write(jsonData, file.path(outputFolder,"output.json"))
  
