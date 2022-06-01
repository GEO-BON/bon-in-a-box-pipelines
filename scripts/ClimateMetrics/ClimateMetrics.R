

# Install required packages
packages <- c("gdalcubes", "rstac", "tibble", "sp", "sf", "dplyr", "rgbif", "tidyr", "stars", "raster", "terra", "rjson")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)


## Load required packages
library("gdalcubes")
library("rstac")
library("tibble")
library("sp")
library("sf")
library("dplyr")
library("rgbif")
library("tidyr")
library("stars")
library("ggplot2")
library("raster")
library("terra")
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
source("/scripts/ClimateMetrics/funcClimateMetrics.R")
#source("/scripts/stacCatalogue/stac_functions.R")




## Outputing result to JSON

output <- list("local velocity" = local_velocity,
               "forward velocity" = forward_velocity,
               "backward velocity" = backward_velocity,
               "climate rarity" = climate_rarity)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))




