# This is to look at change in BII over time
library("rjson")
library("terra")
library("dplyr")

source(paste(Sys.getenv("SCRIPT_LOCATION"), "/data/loadFromStacFun.R", sep = "/"))

input <- biab_inputs()

start_yr <- paste0("bii_nhm_10km_", input$start_year)
end_yr <- paste0("bii_nhm_10km_", input$end_year)

# Load rasters as a raster stack
rasters <- terra::rast(c(input$rasters))
print(names(rasters))

first_raster <- rasters[[names(rasters)==start_yr]]
end_raster <- rasters[[names(rasters)==end_yr]]

print(names(first_raster))
# Summarise
bii_change <- end_raster-first_raster

# Output
bii_change_path <- file.path(outputFolder, "BII_change.tif")
writeRaster(bii_change, bii_change_path)
biab_output("bii_change", bii_change_path)

