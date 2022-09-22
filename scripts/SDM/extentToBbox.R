
## Install required packages
packages <- c("rjson", "dplyr")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## Load required packages

library("rjson")
library("raster")
library("dplyr")
## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/sdmUtils.R", sep = "/"))

## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

shp <- sf::st_read(input$extent)
bbox <- shp_to_bbox(shp, proj_to = "EPSG:4326")
bbox.df <- bbox_to_df(bbox)
bbox.df.path <- file.path(outputFolder, "bbox.tsv")
write.table(bbox.df, bbox.df.path,
             append = F, row.names = F, col.names = T, sep = "\t")

output <- list("bbox" =  bbox.df.path)
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))