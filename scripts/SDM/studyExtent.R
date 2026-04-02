## Install required packages
library(rjson)
library(sf)
## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/studyExtentFunc.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/sdmUtils.R", sep = "/"))

input <- biab_inputs()
print("Inputs: ")
print(input)
bbox <- input$bbox_crs$bbox
crs <- paste0(input$bbox_crs$CRS$authority, ":", input$bbox_crs$CRS$code)

if (input$presence != "") {
  presence <- read.table(file = input$presence, sep = "\t", header = TRUE)
} else {
  presence <- NULL
}

if (is.numeric(input$width_buffer)) {
  width_buffer <- input$width_buffer
} else {
  width_buffer <- NULL
}

study_extent <- create_study_extent(presence,
  lon = "lon",
  lat = "lat",
  proj = crs,
  method = input$method,
  dist_buffer = width_buffer,
  shapefile_path = NULL,
  bbox = bbox
)

study_extent_shp <- file.path(outputFolder, "study_extent.shp")
sf::st_write(study_extent, study_extent_shp, append = FALSE)

biab_output("area_study_extent", sf::st_area(study_extent) / 1000000)
biab_output("study_extent", study_extent_shp)

