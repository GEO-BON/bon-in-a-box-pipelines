

## Install required packages
packages <- c("terra", "rjson", "raster", "dplyr", "rstac",
              "CoordinateCleaner", "stars", "gdalcubes")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## Load required packages
library("terra")
library("rjson")
library("raster")
library("CoordinateCleaner")
library("dplyr")
library("stars")
library("rstac")
library("gdalcubes")

## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/selectBackgroundFunc.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/sdmUtils.R", sep = "/"))

## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")

setwd(outputFolder)

input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

study_extent <- sf::st_read(input$extent)
predictors <- terra::rast(input$predictors)
presence <- read.table(file = input$presence, sep = '\t', header = TRUE)

# Sometimes it is an empty character instead
if(input$raster == ""){
  input$raster = NULL
}

# Optional.. so without input it should be NULL
if(grepl("raster", input$method_background) & !is.null(input$raster)){
  # Read in path to file
  heatmap <- terra::rast(input$raster)
  # This step is *slow*; an alternative would be better
  # The same is applied to 'loadPredictorsFunc.R' as well
  heatmap <- terra::project(heatmap, predictors)
}else{
  heatmap <- NULL
}


background <- create_background(
  predictors = predictors, 
  obs = presence,
  mask = study_extent,
  method = input$method_background,
  n = input$n_background,
  width_buffer = input$width_buffer,
  density_bias = input$density,
  raster = heatmap)


background.output <- file.path(outputFolder, "background.tsv")
write.table(background, background.output,
            append = F, row.names = F, col.names = T, sep = "\t")
output <- list(
  "n_background" =  nrow(background),
  "background"= background.output
)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

