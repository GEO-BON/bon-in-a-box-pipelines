## Load required packages
library("terra")
library("rjson")
library("raster")
library("CoordinateCleaner")
library("dplyr")

## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "filtering/cleanCoordinatesFunc.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/sdmUtils.R", sep = "/"))

input <- biab_inputs()
print("Inputs: ")
print(input)

presence <- read.table(file = input$presence, sep = "\t", header = TRUE)

# Import of predictors
predictors <- terra::rast(unlist(input$predictors))
proj <- terra::crs(predictors)

# Projecting observations into predictors projection
presence <- create_projection(presence,
  lon = "decimal_longitude", lat = "decimal_latitude",
  proj_from = "+proj=longlat +datum=WGS84", proj_to = proj, new_lon = "lon", new_lat = "lat"
)

# Cleaning the data
clean_presence <- clean_coordinates(
  x = presence,
  predictors = predictors,
  species_name = species,
  unique_id = "id",
  lon = "lon",
  lat = "lat",
  species_col = "scientific_name",
  tests = input$tests,
  threshold_env = input$threshold_env,
  report = F,
  value = "clean"
)
clean_presence <- clean_presence |> # summary = TRUE means the observations was identified as an outlier at least once during the cleaning procedure
  dplyr::select(id, scientific_name, lon, lat)

clean_presence.output <- file.path(outputFolder, "clean_presence.tsv")

write.table(clean_presence, clean_presence.output,
  append = F, row.names = F, col.names = T, sep = "\t"
)

biab_output("n_clean", nrow(clean_presence))
biab_output("clean_presence", clean_presence.output)