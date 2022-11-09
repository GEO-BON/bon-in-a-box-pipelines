
# Calculating proportion of Protected Areas (polygons) within a raster pixel (e.g., 1000m)

# world database on protected areas (wdpa) source: https://www.protectedplanet.net/en

packages <- c("sf", "wdpar", "terra", "exactextractr", "dplyr", "raster", "rjson", "Rcpp", "remotes")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)


# libraries
library("rjson")
library("sf")
library("wdpar")
library("terra")
library("exactextractr")
library("dplyr")
library("raster")
library("Rcpp")

library("remotes")

remotes::install_github("dickoa/prepr")
library("prepr")

options(timeout = max(60000000, getOption("timeout")))


## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder

setwd(outputFolder)
input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


# Load functions

source("/scripts/protectedAreas/protectedAreasPropFunc.R")

bbox <- st_bbox(c(xmin = input$bbox[1], xmax = input$bbox[2], 
                    ymax = input$bbox[3], ymin = input$bbox[4]), crs = st_crs(input$crs))


print("This script creates a raster layer showing the proportion of protected areas (PAs) within a given pixel size...")

tif <- protected_areas(country = input$country,
                       bbox = bbox,
                       crs = input$crs,
                       pixel_size = input$pixel_size,
                       habitat_type = input$habitat_type
)



output_tif <- file.path(outputFolder, "Protected_areas_prop.tif")
raster::writeRaster(x = tif,
                    output_tif,
                    overwrite = TRUE,
                    format='COG',
                    options=c("COMPRESS=DEFLATE")
)





# Outputing result to JSON
output <- list("output_tif" = output_tif)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))



