## Environment variables available
# Script location can be used to access other scripts
print(Sys.getenv("SCRIPT_LOCATION"))

## Install required packages
packages <- c("rjson")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")

## Script body
example_jpg = file.path(outputFolder, "example.jpg")
if(!file.exists(example_jpg)) {
    download.file("https://geobon.org/wp-content/uploads/2018/01/default-image.png", example_jpg, "auto")
}

example_tiff = file.path(outputFolder, "utmsmall.tif")
if(!file.exists(example_tiff)) {
    download.file("https://github.com/yeesian/ArchGDALDatasets/raw/master/data/utmsmall.tif", example_tiff, "auto")
}


## Outputing result to JSON
output <- list("Heat map" = example_tiff, 
                Uncertainty = example_jpg) 
                
library("rjson")
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

# (If we get a problem with encoding, we could use utf-8 library to clean the output, since the server reads it as utf-8)