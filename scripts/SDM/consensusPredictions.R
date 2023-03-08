
## Install required packages
packages <- c("terra", "rjson", "raster", "dplyr", "dismo")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## Load required packages

library("terra")
library("rjson")
library("raster")
library("dplyr")
library("dismo")
## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/consensusPredictionsFunc.R", sep = "/"))



input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

presence_background <- read.table(file = input$presence_background, sep = '\t', header = TRUE) 
predictions <-  terra::rast(input$predictions)
consensus <- model_consensus(predictions, presence_background, input$consensus_method,
    input$min_auc, input$top_k_auc)
output_consensus<- file.path(outputFolder, "consensus.tif")

if(!is.null(output_consensus)) {
    terra::writeRaster(consensus, output_consensus, overwrite = T, gdal=c("COMPRESS=DEFLATE"), filetype="COG")
}

output <- list("consensus" =  output_consensus)
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))