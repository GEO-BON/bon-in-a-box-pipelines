## Environment variables available
# Script location can be used to access other scripts
print(Sys.getenv("SCRIPT_LOCATION"))

## Install required packages
packages <- c("rgbif", "rjson", "raster", "dplyr")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## Install required packages
library("rgbif")
library("dplyr")
library("raster")
library("rjson")
## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


# Loading data from GBIF (https://www.gbif.org/)
#loadGbifData <- function(species, limit) {
  
gbifData <- occ_data(scientificName = input$species, hasCoordinate = T, limit=500) 
  data <- gbifData$data
  
  if (is.null(data)) {
    message(sprintf("No observation found for species %s", species))
  } else {
    data <- data %>% dplyr::select(key, species, decimalLongitude, decimalLatitude, year, month, day, datasetName, basisOfRecord) %>%
      dplyr::rename(id = key, scientific_name = species) %>%
      mutate(created_by = 'GBIF')%>%
      mutate(id = as.double(id))
    message(sprintf("%s observation loaded", nrow(data)))
    
#    if (nrow(data) == limit) {
 #     message("Number of observations equals the limit number. Some observations may be lacking.")
      
 #   }
  }
#  write.table(data, sprintf("%s/observationGbif.csv", getwd()),
#             append = F, row.names = F, col.names = T, sep = ";")
 
 #output <- list("observation" =  sprintf("%s/observationGbif.csv", getwd())) 
  output <- list("n.observations" =  nrow(data)) 
  jsonData <- toJSON(output, indent=2)
  write(jsonData, file.path(outputFolder,"output.json"))
  