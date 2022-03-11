## Environment variables available
# Script location can be used to access other scripts
print(Sys.getenv("SCRIPT_LOCATION"))

## Install required packages
#packages <- c("gdalcubes", "rjson", "raster", "dplyr", "rstac", "tibble", "sp", "sf", "rgdal", "curl", "RCurl")

#new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
#if(length(new.packages)) install.packages(new.packages)
#install.packages("gdalcubes")
## Load required packages
library("gdalcubes")
library("rjson")
library("raster")
library("dplyr")
library("rstac")
library("tibble")
library("sp")
library("sf")

#install.packages("crul")
#library("crul")
#library("curl")
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

print(input)
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

obs.proj <-  projectCoords(obs.coords, lon = "decimalLongitude", lat = "decimalLatitude", proj.from = input$srs.obs, proj.to = input$srs.cube)
#obs.proj <-  setNames(data.frame(obs.proj), c("lon", "lat"))

#value.points <- query_points(cube, obs.proj$lon, obs.proj$lat, 
 # pt = rep(as.Date(input$t0), length(obs.proj$lon)), srs(cube)) %>% data.frame()
#obs <- bind_cols(obs,
 # value.points)

value.points <- extract_geom(cube, st_as_sf(obs.proj)) 
print(head(value.points))
obs.val <- bind_cols(select(value.points, FID, time) %>% dplyr::rename(id = FID),
          data.frame(obs.proj),
          select(value.points, all_of(input$layers)))

obs.values <- file.path(outputFolder, "obs_values_out.tsv")
write.table(obs.val, obs.values,
             append = F, row.names = F, col.names = T, sep = "\t")


  output <- list(
                  "obs.values" = obs.values
                  ) 
  jsonData <- toJSON(output, indent=2)
  write(jsonData, file.path(outputFolder,"output.json"))
  
