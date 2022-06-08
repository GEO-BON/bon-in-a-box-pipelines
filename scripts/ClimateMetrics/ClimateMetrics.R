

# Install required packages
packages <- c("rstac", "tibble", "sp", "sf", "dplyr", "rgbif", "tidyr", "stars", "raster", "terra", "rjson")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

remotes::install_git("https://github.com/appelmar/gdalcubes_R")
devtools::install_git("ReseauBiodiversiteQuebec/stac-catalogue")


## Load required packages
library("stacatalogue")
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

cube_current <- load_cube(input$collections = 'chelsa-monthly', 
                          input$use.obs = T,
                          input$obs = NULL,
                          
                          input$bbox = NULL,
                          
                          input$buffer.box = 0,
                          
                          input$srs.cube = "EPSG:6623",
                          input$t0 = "1981-01-01",
                          input$t1 = "1983-12-31",
                          input$variable = "tas",
                          input$spatial.res = 10000, # in meters
                          input$temporal.res = "P3Y", # see number of years t0 to t1
                          input$aggregation = "mean",
                          input$resampling = "bilinear"
                         )

cube_future <- load_cube(  input$collections = 'chelsa-clim-proj', 
                           input$use.obs = T,
                           input$obs = NULL,
                           
                           input$bbox = NULL,
                           
                           input$buffer.box = 0,
                           
                           input$rcp = 'ssp126', #ssp126, ssp370, ssp585
                           
                           input$srs.cube = "EPSG:6623",
                           input$time.span = "2041-2070", #"2011-2040", 2041-2070 or 2071-2100
                           input$variable = "bio1",
                           input$spatial.res = 10000, # in meters
                           input$temporal.res = "P1Y", 
                           input$aggregation = "mean",
                           input$resampling = "bilinear"
  
)

tif <- funcClimateMetrics(cube_current,
                          cube_future,
                          metric=input$metric,
                          years_dif = input$years_dif,
                          t_match = input$tmatch,
                          movingWindow = input$movingWindow 
                          )


## Outputing result to JSON

output <- list("output_tif" = tif,
               "metric" = input[['metric']])

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))




