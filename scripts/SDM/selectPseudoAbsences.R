

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
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/selectPseudoAbsencesFunc.R", sep = "/"))
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
pseudoabsences <- sample_pseudoabs(data = presence, x = "lon", y = "lat", n = input$n_pseudoabsences, method = c(input$method, width=input$width, env=predictors), rlayer = predictors, maskval = NULL, calibarea = NULL, sp_name = "sp")

 
pseudoabsences.output <- file.path(outputFolder, "pseudoabsences.tsv")
write.table(pseudoabsences, pseudoabsences.output,
             append = F, row.names = F, col.names = T, sep = "\t")
  output <- list(
                  "n_pseudoabsences" =  nrow(pseudoabsences),
                  "pseudoabsences"= pseudoabsences.output
                  
                  ) 

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

  

