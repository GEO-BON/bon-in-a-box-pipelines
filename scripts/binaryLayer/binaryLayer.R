## Install required packages
packages <- c("rjson", "dplyr", "raster")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## Load required packages

library("rjson")
library("raster")
library("dplyr")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

source("/scripts/binaryLayer/binaryLayerFunc.R")
lc_classes <- input$lc_classes
select_class <- input$select_class
threshold_prop <- input$threshold_prop


# Running binary function
lc_binary <- binary_layer(lc_classes, select_class, threshold_prop)
  

# Saving rasters

for(i in 1:length(names(lc_binary))){
raster::writeRaster(x = lc_binary[[i]],
                    paste0(outputFolder, "/", names(lc_binary[[i]]), ".tif"),
                    format='COG',
                    options=c("COMPRESS=DEFLATE"),
                    overwrite = TRUE
)
}
print(list.files(outputFolder, pattern = ".tif$", full.names = T))

lc_binary_layer <- list.files(outputFolder, pattern="*.tif$", full.names = T)

output <- list("output_binary" = lc_binary_layer)
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))


