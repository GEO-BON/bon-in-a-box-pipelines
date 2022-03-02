## Environment variables available
# Script location can be used to access other scripts
print(Sys.getenv("SCRIPT_LOCATION"))

## Install required packages
#packages <- c("gdalcubes", "rjson", "raster", "dplyr", "rstac", "tibble", "sp", "sf", "rgdal", "curl", "RCurl")
#
install.packages("crul")

#new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
#if(length(new.packages)) install.packages(new.packages)

## Load required packages
library("gdalcubes")
library("rjson")
library("raster")
library("dplyr")
library("rstac")
library("tibble")
library("sp")
library("sf")
#library("RCurl")
library("crul")
options(timeout = max(60000, getOption("timeout")))

## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


# Load functions
source("/scripts/extractPredictors/funcExtractPredictors.R")
obs <- read.table(file = input$obs, sep = '\t', header = TRUE) 

obs.coords <- dplyr::select(obs, decimalLongitude, decimalLatitude)


cube <- 
  loadCube(stac_path = input$stac_path,
           limit = input$limit, 
           collections = c(input$collections), 
           use.obs = T,
           obs = obs.coords,
           srs.obs = input$srs.obs,
           lon = "decimalLongitude",
           lat = "decimalLatitude",
           buffer.box = input$buffer.box,
           layers= input$layers,
           srs.cube = input$srs.cube,
           t0 = input$t0,
           t1 = input$t1,
           spatial.res = input$spatial.res,
           temporal.res = input$temporal.res) 

obs <- bind_cols(obs, 
                 setNames(data.frame(proj.pts), c("lon", "lat"))) 

value.points <- query_points(cube, obs$lon, obs$lat, pt = rep(as.Date(input$t0), length(obs$lon)), srs(cube))
obs <- bind_cols(obs,
  value.points)


obs.values <- file.path(outputFolder, "obs_values.tsv")
write.table(obs, obs.values,
             append = F, row.names = F, col.names = T, sep = "\t")


  output <- list(
                  "obs.values" = obs.values
                  ) 
  jsonData <- toJSON(output, indent=2)
  write(jsonData, file.path(outputFolder,"output.json"))
  
