## Load required packages
library("terra")
library("rjson")
library("raster")
library("CoordinateCleaner")
library("dplyr")
library("stars")
library("rstac")
library("gdalcubes")

## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/selectBackgroundFunc.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/sdmUtils.R", sep = "/"))

input <- biab_inputs()
print("Inputs: ")
print(input)

study_extent <- sf::st_read(input$extent)
predictors <- terra::rast(input$predictors)
presence <- read.table(file = input$presence, sep = "\t", header = TRUE)

# Sometimes it is an empty character instead
if (input$raster == "") {
  input$raster <- NULL
}

# Optional.. so without input it should be NULL
if (grepl("raster", input$method_background) & !is.null(input$raster)) {
  # Read in path to file
  heatmap <- terra::rast(input$raster)
  # This step is *slow*; an alternative would be better
  # The same is applied to 'loadPredictorsFunc.R' as well
  heatmap <- terra::project(heatmap, predictors)
} else {
  heatmap <- NULL
}

background <- create_background(
  predictors = predictors,
  obs = presence,
  mask = study_extent,
  method = input$method_background,
  n = input$n_background,
  width_buffer = input$width_buffer,
  density_bias = input$density,
  raster = heatmap
)

background_output <- file.path(outputFolder, "background.tsv")
write.table(background, background_output,
  append = F, row.names = F, col.names = T, sep = "\t"
)

biab_output("n_background", nrow(background))
biab_output("background", background_output)
