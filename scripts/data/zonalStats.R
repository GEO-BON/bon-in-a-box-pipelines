## This is a script to load layers from the STAC catalog and calculate zonal statistics for a polygon (country or region) of interest
## Modified from Load From STAC

library("rjson")
library("dplyr")
library("gdalcubes")
library("sf")
sf_use_s2(FALSE)

# load from STAC function to load data cube
source(paste(Sys.getenv("SCRIPT_LOCATION"), "/data/loadFromStacFun.R", sep = "/"))

input <- fromJSON(file=file.path(outputFolder, "input.json"))

# create bounding box
bbox <- sf::st_bbox(c(xmin = input$bbox[1], ymin = input$bbox[2],
            xmax = input$bbox[3], ymax = input$bbox[4]), crs = sf::st_crs(input$proj)) 

# Collections items
if (length(input$collections_items) == 0) {
    stop('Please specify collections_items') # if no collections items are specified
} else {
    collections_items <- input$collections_items
}

# define study area
if (is.null(input$studyarea_file)){ # if there is no study area file input
  if (is.null(input$state)){ # if there is only a country input (no state) 
    input$country <- gsub(" ", "+", input$country) # Change spaces to + signs to work in the URL 
    study_area<- paste0("https://geoio.biodiversite-quebec.ca/country_geojson/?country_name=", input$country) # study area url 
  } else { # if a state is defined
   input$country <- gsub(" ", "+", input$country)
   input$state <- gsub(" ", "+", input$state)
    study_area<- paste0("https://geoio.biodiversite-quebec.ca/state_geojson/?country_name=", input$country, "&state_name=", input$state)
  } } else {study_area <- input$studyarea_file}

# Read in study area polygon
study_area_polygon<- sf::st_read(study_area)  # load study area as sf object


# Load cube using the loadFromStacFun
dat_cube <- load_cube(stac_path=input$stac_url, collections=collections_items, bbox=bbox,
                        srs.cube = input$proj)


# Calculate summary statistics - mean
stats <- gdalcubes::extract_geom(cube=dat_cube, sf=study_area_polygon, FUN=mean)
stats_path <- file.path(outputFolder, "stats.csv")

output <- list("stats" = stats_path)
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))


