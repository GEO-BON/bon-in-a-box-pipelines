

# Install required packages

packages <- c("rstac", "tibble", "sp", "sf", "rgdal",  "lubridate", "dplyr",
              "rgbif", "tidyr", "stars", "raster", "terra", "rjson", "RCurl")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)


library("devtools")
if (!"stacatalogue" %in% installed.packages()[,"Package"]) devtools::install_github("ReseauBiodiversiteQuebec/stac-catalogue")
if (!"gdalcubes" %in% installed.packages()[,"Package"]) devtools::install_github("appelmar/gdalcubes_R")

## Load required packages
library("rjson")
library("gdalcubes")
library("stacatalogue")
library("rstac")
library("tibble")
library("sp")
library("rgdal")
library("lubridate")
library("RCurl")
library("sf")
library("dplyr")
library("rgbif")
library("tidyr")
library("stars")
library("ggplot2")
library("raster")
library("terra")
options(timeout = max(60000000, getOption("timeout")))


setwd(outputFolder)
input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


# Load functions

source("/scripts/climateMetrics/climateMetricsFunc.R")


bbox <- st_bbox(c(xmin = input$bbox[1], ymin = input$bbox[2], 
        xmax = input$bbox[3], ymax = input$bbox[4]), crs = st_crs(input$srs_cube))

n_year <- as.integer(substr(input$t1, 1, 4)) - as.integer(substr(input$t0, 1, 4)) + 1 
temporal_res <- paste0("P", n_year, "Y")

print("Loading current climate...")
cube_current <- stacatalogue::load_cube(collections = 'chelsa-monthly', 
                          bbox = bbox,
                          t0 = input$t0,
                          t1 = input$t1,
                          limit = 5000,
                          variable = "tas",
                          srs.cube = input$srs_cube,
                          spatial.res = input$spatial_res, # in meters
                          temporal.res = temporal_res, # see number of years t0 to t1
                          aggregation = input$aggregation,
                          resampling = "bilinear"
                         )
print("Loading current climate loaded.")

print("Loading future climate...")
cube_future <- stacatalogue::load_cube_projection(collections = 'chelsa-clim-proj',            
                          bbox = bbox,
                          limit = 5000,
                          srs.cube = input$srs_cube,
                          rcp = input$rcp, #ssp126, ssp370, ssp585
                          time.span =input$time_span, #"2011-2040", 2041-2070 or 2071-2100
                          variable = "bio1",
                        spatial.res = input$spatial_res,# in meters
                           temporal.res = "P1Y",  
                           aggregation = input$aggregation,
                           resampling = "bilinear"
  
)

print("Future climate loaded.")

metric <- input$metric
if (is.null(metric)) metric <- "rarity"

print(paste("Calculating", metric, "metric..."))

tif <- climate_metrics(cube_current,
                          cube_future,
                          metric ,
                           t_match = input$t_match
                          )

for(i in 1:length(names(tif))){
 raster::writeRaster(x = tif[[i]],
                      paste0(outputFolder, "/", names(tif[[i]]), ".tif"),
                      format='COG',
                     options=c("COMPRESS=DEFLATE"),
                     overwrite = TRUE)
}



#output_tif <- file.path(outputFolder, paste0(metric, ".tif"))
output_tif <- list.files(outputFolder, pattern="*.tif$", full.names = T)
#raster::writeRaster(x = tif,
  #                       output_tif,
  #                        format='COG',
  #                        options=c("COMPRESS=DEFLATE"),
  #                       overwrite = TRUE)

print("Metrics saved.")


# Outputing result to JSON
output <- list(
  "output_tif" = output_tif,
  "metric" = metric
)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))




