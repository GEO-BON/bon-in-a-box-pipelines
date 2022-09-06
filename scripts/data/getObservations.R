## Environment variables available
# Script location can be used to access other scripts
print(Sys.getenv("SCRIPT_LOCATION"))

## Install required packages
packages <- c("rgbif", "rjson", "raster", "dplyr", "stringr")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## Load required packages
library("rgbif")
library("dplyr")
library("raster")
library("rjson")
library("stringr")

## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "data/getObservationsFunc.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/sdmUtils.R", sep = "/"))

## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

if (!is.null(input$bbox_table) && input$bbox_table !="...") {
  bbox <- read.table(file = input$bbox_table, sep = '\t', header = FALSE) 
  bbox <- bbox[,2]
} else if (length(input$bbox) == 4) {
  bbox <- input$bbox
} else {
  bbox <- NULL
}


if (input$country == "...") {
  country <- NULL
} else {
  country <- input$country
}

occurrence_status <- str_split(input$occurrence_status, " ")[[1]]
# Loading data from GBIF (https://www.gbif.org/)
obs <- get_observations(database = "gbif", 
  species = input$species,
           year_start = input$year_start,
           year_end = input$year_end,
           country = country,
           bbox = bbox,
           occurrence_status = occurrence_status,
           limit = input$limit)
print(obs)
obs.data <- file.path(outputFolder, "obs_data.tsv")
write.table(obs, obs.data,
             append = F, row.names = F, col.names = T, sep = "\t")


  output <- list(
                  "n_presence" =  nrow(obs),
                  "presence" = obs.data
                  ) 
  jsonData <- toJSON(output, indent=2)
  write(jsonData, file.path(outputFolder,"output.json"))
  
