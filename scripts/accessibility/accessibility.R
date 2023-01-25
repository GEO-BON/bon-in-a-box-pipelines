# Creating the accessibility layer, using "A global map of travel time to cities to assess inequalities in accessibility in 2015 by Weiss et al 2018.  (https://www.nature.com/articles/nature25181)


## Install required packages

library("devtools")
if (!"stacatalogue" %in% installed.packages()[,"Package"]) devtools::install_github("ReseauBiodiversiteQuebec/stac-catalogue")

#devtools::install_github("ReseauBiodiversiteQuebec/stac-catalogue", upgrade = "never")
#devtools::install_local("C:/stac-catalogue", upgrade = "never")
#source("C:/stac-catalogue/R/stac_functions.R")

packages <- c("terra", "rjson", "raster", "dplyr", "CoordinateCleaner", "lubridate", "rgdal", "remotes")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library("remotes")
if (!"gdalcubes_R" %in% installed.packages()[,"Package"]) devtools::install_github("ReseauBiodiversiteQuebec/stac-catalogue")


##devtools::install_local("loadLandCover/stac-catalogue-main.zip", 
#  repos = NULL, 
#   type = "source")

## Load required packages
library("terra")
library("rjson")
library("raster")
library("dplyr")
library("stacatalogue")
library("gdalcubes")
library("RCurl")
options(timeout = max(60000000, getOption("timeout")))

## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


# Tranform the vector to a bbox object

bbox <- sf::st_bbox(c(xmin = input$bbox[1], ymin = input$bbox[2], 
                      xmax = input$bbox[3], ymax = input$bbox[4]), crs = sf::st_crs(input$srs_cube))


n_year <- as.integer(substr(input$t1, 1, 4)) - as.integer(substr(input$t0, 1, 4)) + 1 
temporal_res <- paste0("P", n_year, "Y")

  accessibility <- stacatalogue:: load_cube(stac_path = "https://io.biodiversite-quebec.ca/stac/",
                                        collections = c("accessibility_to_cities"), 
                                        bbox = bbox,
                                        srs.cube = input$srs_cube,
                                        t0 = "2015-01-01",
                                        t1 = "2015-01-01",
                                        spatial.res = 1000, # in meters
                                        temporal.res =  "P1D",
                                      #  layers='data',
                                        aggregation = "mean",
                                        resampling = "near")%>% cube_to_raster("raster")



  
  output_tif <- file.path(outputFolder, "accessibility.tif")
  raster::writeRaster(x = accessibility,
                      output_tif,
                      format='COG',
                      options=c("COMPRESS=DEFLATE"),
                      overwrite = TRUE)
  
  
  # Outputing result to JSON
  output <- list("output_tif" = output_tif)
  
  jsonData <- toJSON(output, indent=2)
  write(jsonData, file.path(outputFolder,"output.json"))
  
  