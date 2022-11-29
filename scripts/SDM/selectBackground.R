

## Install required packages
packages <- c("terra", "rjson", "raster", "dplyr", "CoordinateCleaner", "stars")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## Load required packages
library("terra")
library("rjson")
library("raster")
library("CoordinateCleaner")
library("dplyr")
library("stars")

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
predictors <- terra::rast(unlist(input$predictors))
presence <- read.table(file = input$presence, sep = '\t', header = TRUE)

background <- create_background(
  predictors = predictors, 
  obs = presence,
  mask = study_extent,
  method = "random", #will select random points in predictors_study_extent area
  n = input$n_background,
  width_buffer = input$width_buffer,
  density_bias = input$density) 

 
background.output <- file.path(outputFolder, "background.tsv")
write.table(background, background.output,
             append = F, row.names = F, col.names = T, sep = "\t")
  output <- list(
                  "n_background" =  nrow(background),
                  "background"= background.output
                  
                  ) 

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

  

