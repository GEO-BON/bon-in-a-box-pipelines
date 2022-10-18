

## Install required packages

## Load required packages

library("terra")
library("rjson")
library("raster")
library("dplyr")
library("embarcadero")

## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "runSDM/funcRunSDM.R", sep = "/"))
## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


presence_background <- read.table(file = input$presence_background, sep = '\t', header = TRUE) 

# Format for bart() function
presence_background <- presence_background |> data.frame()
predictors <- raster::stack(input$predictors)

covars <- names(predictors)
sdm <- bart(y.train = presence_background[,'pa'],
            x.train = presence_background[, covars],
            keeptrees = TRUE) 
maps <- predict(sdm, predictors, quiet=TRUE, quantiles=c(0.025, 0.975))
map <- maps[[1]] #posterior mean
CI <- map[[3]]-map[[2]]  #Credible interval width


output_pred <- file.path(outputFolder, "sdm_pred.tif")
raster::writeRaster(x = map,
                          filename = output_pred,
                          overwrite = TRUE)

output_uncertainty <- file.path(outputFolder, "uncertainty.tif")
raster::writeRaster(x = CI,
                          output_uncertainty,
                          overwrite = TRUE)
 
output <- list("sdm_pred" = output_pred,
  "sdm_uncertainty" =  output_uncertainty
                  ) 

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))