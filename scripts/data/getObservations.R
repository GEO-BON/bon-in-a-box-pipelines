## Environment variables available
# Script location can be used to access other scripts
print(Sys.getenv("SCRIPT_LOCATION"))

## Install required packages
packages <- c("rgbif", "rjson", "raster", "dplyr", "stringr")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## Load required packages
library("rgbif")
library("dplyr")
library("raster")
library("rjson")
library("stringr")

## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "data/getObservationsFunc.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/sdmUtils.R", sep = "/"))



input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


# Tranform the vector to a bbox object
bbox_wgs84 <- sf::st_bbox(c(xmin = input$bbox[1], ymin = input$bbox[2], 
            xmax = input$bbox[3], ymax = input$bbox[4]), crs = sf::st_crs(input$proj)) %>% sf::st_as_sfc() %>% sf::st_transform(crs = "EPSG:4326") %>% 
        sf::st_bbox()


if (input$country == "..." | length(input$country) < 2) {
  country <- NULL
} else {
  country <- input$country
}

if (input$bbox_buffer == "...") {
  bbox_buffer <- 0
} else {
  bbox_buffer <- input$bbox_buffer }

occurrence_status <- str_split(input$occurrence_status, " ")[[1]]

# Loading data from GBIF (https://www.gbif.org/)
obs <- get_observations(database = "gbif", 
  species = input$species,
           year_start = input$year_start,
           year_end = input$year_end,
           country = country,
           bbox = bbox_wgs84,
           occurrence_status = occurrence_status,
           limit = input$limit)

# Creating the bbox
  obs_pts <- stacatalogue::project_coords(obs,
                            lon = "decimal_longitude",
                            lat = "decimal_latitude",
                            proj_from = "+proj=longlat +datum=WGS84",
                            proj_to = input$proj)
bbox <- stacatalogue::points_to_bbox(obs_pts, buffer = bbox_buffer)
bbox <-c(bbox$xmin, bbox$ymin, bbox$xmax, bbox$ymax)

# Outputs
obs.data <- file.path(outputFolder, "obs_data.tsv")
write.table(obs, obs.data,
             append = F, row.names = F, col.names = T, sep = "\t")

obs.bbox <- file.path(outputFolder, "obs_bbox.tsv")
write.table(bbox, obs.bbox,
             append = F, row.names = F, col.names = T, sep = "\t")
  output <- list(
                  "n_presence" =  nrow(obs),
                  "presence" = obs.data,
                  "bbox" = obs.bbox
                  ) 
  jsonData <- toJSON(output, indent=2)
  write(jsonData, file.path(outputFolder,"output.json"))
  
