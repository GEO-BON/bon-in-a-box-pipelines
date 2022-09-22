## Environment variables available
# Script location can be used to access other scripts
## Install required packages
packages <- c("rjson", "raster", "dplyr", "tibble", "sp", "sf", "ratlas", "rgbif")

new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
## Load required packages
library("rjson")
library("raster")
library("dplyr")
library("sp")
library("sf")
library("tibble")
library("ratlas")
library("rgbif")

# Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "data/loadObservationsFunc.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/sdmUtils.R", sep = "/"))


## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


observations <- load_observations(species = input$species,
           data_source = input$data_source,
           year_start = 1980,
           year_end = 2020,
           extent_wkt = NULL,
           extent_shp = NULL,
           proj_shp = NULL,
           xmin = NA,
           ymin = NA,
           xmax = NA,
           ymax = NA,
           bbox = NULL,
           limit = 1000)
