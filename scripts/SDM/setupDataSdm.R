

## Install required packages
packages <- c("terra", "rjson", "raster", "dplyr", "ENMeval", "devtools")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

library("devtools")
if (!"stacatalogue" %in% installed.packages()[,"Package"]) devtools::install_github("ReseauBiodiversiteQuebec/stac-catalogue")
if (!"gdalcubes" %in% installed.packages()[,"Package"]) devtools::install_github("appelmar/gdalcubes_R")


## Load required packages

library("terra")
library("rjson")
library("raster")
library("dplyr")
library("gdalcubes")
library("ENMeval")
library("stacatalogue")
#library("devtools")
#install.packages("ENMeval")
#devtools::install_github("ReseauBiodiversiteQuebec/ratlas")
#devtools::install_github("ReseauBiodiversiteQuebec/sdm-pipeline")


## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/setupDataSdmFunc.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/loadPredictorsFunc.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/sdmUtils.R", sep = "/"))



input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

presence <- read.table(file = input$presence, sep = '\t', header = TRUE) 
background <- read.table(file = input$background, sep = '\t', header = TRUE) 
predictors <- terra::rast(unlist(input$predictors))
# names(predictors) <- input$layers

presence_bg_vals <- setup_presence_background(
  presence = presence,
  background = background,
  predictors = predictors,
  partition_type = input$partition_type,
  runs_n = input$runs_n,
  boot_proportion = input$boot_proportion,
  cv_partitions = input$cv_partitions,
  seed=NULL)

presence_background.output <- file.path(outputFolder, "presence_background.tsv")

write.table(presence_bg_vals, presence_background.output,
             append = F, row.names = F, col.names = T, sep = "\t")

output <- list("presence_background" =  presence_background.output
                  ) 
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))