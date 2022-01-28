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

library("rjson")
input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

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
# notice that the warning string is not part of the yml spec, so it cannot be used by other scripts, but will still be displayed.
output <- list("warning" = "This is just an example. In case you have a very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very long warning it will need to be unfolded to see it all.",
                "number" = input$intensity * 3,
                "heat_map" = example_tiff, 
                "other_map" = example_tiff,
                "some_picture" = example_jpg) 
                
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

# (If we get a problem with encoding, we could use utf-8 library to clean the output, since the server reads it as utf-8)