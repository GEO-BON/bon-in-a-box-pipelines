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
source("/scripts/loadObservations/funcLoadObservations.R")
source("/scripts/utils/utils.R")

obs_gbif <- load_observations(species = "Glyptemys insculpta",
           data_source = "gbif",
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

obs_atlas <- load_observations(species = "Glyptemys insculpta",
           data_source = "atlas",
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