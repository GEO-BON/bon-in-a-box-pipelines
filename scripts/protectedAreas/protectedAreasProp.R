
# Calculating proportion of Protected Areas (polygons) within a raster pixel (e.g., 1000m)

# world database on protected areas (wdpa) source: https://www.protectedplanet.net/en

packages <- c("sf",  "terra", "exactextractr", "dplyr",  "rjson", "Rcpp", "remotes", "wdman", "webdriver")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

remotes::install_github("prioritizr/wdpar@fixes")
# libraries
library("rjson")
library("sf")
library("wdpar")
library("terra")
library("exactextractr")
library("dplyr")
library("Rcpp")
library("wdman")
library("remotes")
library("webdriver")

webdriver::install_phantomjs()


if (!"prepr" %in% installed.packages()[,"Package"]) remotes::install_github("dickoa/prepr")

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
                       habitat_type = input$habitat_type,
                       status = input$status
)



output_tif <- file.path(outputFolder, paste0("Protected_areas_prop",  ".tif"))
terra::writeRaster(x = tif,
                    output_tif,
                    overwrite = TRUE,
                    filetype='COG',
                    wopt= list(gdal=c("COMPRESS=DEFLATE"))
)





# Outputing result to JSON
output <- list("output_tif" = output_tif)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))



