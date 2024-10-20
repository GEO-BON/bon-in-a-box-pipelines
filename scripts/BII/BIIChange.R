# This is to look at change in BII over time
library("rjson")
library("terra")
library("dplyr")

source(paste(Sys.getenv("SCRIPT_LOCATION"), "/data/loadFromStacFun.R", sep = "/"))

input <- fromJSON(file=file.path(outputFolder, "input.json"))

output<- tryCatch({

start_yr <- paste0("bii_nhm_10km_", input$start_year)
end_yr <- paste0("bii_nhm_10km_", input$end_year)

# Load rasters as a raster stack
rasters <- terra::rast(c(input$rasters))
print(names(rasters))

first_raster <- rasters[[names(rasters)==start_yr]]
end_raster <- rasters[[names(rasters)==end_yr]]

print(names(first_raster))
# Summarise
bii_change <- first_raster-end_raster

# Output
bii_change_path <- file.path(outputFolder, "BII_change.tif")
writeRaster(bii_change, bii_change_path)

output <- list("bii_change"=bii_change_path)
}, error = function(e) { list(error = conditionMessage(e)) })

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))