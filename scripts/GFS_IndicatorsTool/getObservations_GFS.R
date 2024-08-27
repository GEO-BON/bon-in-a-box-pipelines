## Environment variables available
# Script location can be used to access other scripts
print(Sys.getenv("SCRIPT_LOCATION"))

## Install required packages
packages <- c("rgbif", "rjson", "raster", "dplyr", "stringr", 'rnaturalearth','rnaturalearthdata','sf')
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## Load required packages
library("rgbif")
library("dplyr")
library("raster")
library("rjson")
library("stringr")
library("rnaturalearth")
library("sf")

## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "data/getObservationsFunc.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/sdmUtils.R", sep = "/"))



input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

## check type of population input

if (input$POPinput=='population_polygons') { # if population polygons already defined, do nothing
  
  # create empty dataframe
  obs = data.frame()
  
  print('Population polygons already defined, no need to get GBIF observations')
  
} else if (input$POPinput=='species_obs'){  # if species occurrences already known, report occurrence table as output
  
  # load points from file
  obs = read.table(input$species_obs, header=T)
  
  print('Species observations already defined, no need to get GBIF observations')
  
  
} else if (input$POPinput%in%c('countries','bbox')) { # if observation needs to be computed, get bounding box and follow normal behaviour

  print('Getting GBIF observations...')
  

# Tranform the vector to a bbox object
bbox_wgs84 <- sf::st_bbox(c(xmin = input$bbox[1], ymin = input$bbox[2], 
            xmax = input$bbox[3], ymax = input$bbox[4]), crs = sf::st_crs(input$proj)) %>% sf::st_as_sfc() %>% sf::st_transform(crs = "EPSG:4326") %>% 
        sf::st_bbox()

country <- input$country
if (!is.null(country) && nchar(country) < 2) {
  print("Invalid country")
  country <- NULL
}

bbox_buffer <- input$bbox_buffer
if (is.null(bbox_buffer)) {
  bbox_buffer <- 0
}

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

## if countries where specified, filter occurrences only within countries boundaries
if (input$POPinput=='countries') {
  
  ## get countries polygons
  country<-input$countries
  country_poly = ne_states(geounit=country)
  
  ## transform observations to spatial points
  points = obs[,c("decimal_longitude", "decimal_latitude")]
  colnames(points) = c("longitude","latitude")
  
  ###Define the coordinates of the center points (longitude, latitude)
  points_sf <- st_as_sf(points, coords = c("longitude","latitude"), crs = 4326)
  
  ### Find intersection of points with country polygons
  pt_intersection = as.numeric(st_intersects(points_sf, country_poly))

  ### Subset observations
  obs = obs[is.na(pt_intersection)==F,]
  
}

# Creating the bbox
  obs_pts <- stacatalogue::project_coords(obs,
                            lon = "decimal_longitude",
                            lat = "decimal_latitude",
                            proj_from = "+proj=longlat +datum=WGS84",
                            proj_to = input$proj)

}


## Write output
obs.data <- file.path(outputFolder, "obs_data.tsv")
write.table(obs, obs.data,
            append = F, row.names = F, col.names = T, sep = "\t", quote=F)

output <- list("n_presence" =  nrow(obs),
                  "presence" = obs.data) 
  jsonData <- toJSON(output, indent=2)
  write(jsonData, file.path(outputFolder,"output.json"))
  
