
## Install required packages
packages <- c("rjson", "dplyr")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## Load required packages

library("rjson")
library("raster")
library("dplyr")
## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/sdmUtils.R", sep = "/"))


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

proj_to <- input$proj_to


if (input$source == "df_coordinates") {
df <- read.table(file = input$df_coordinates, sep = '\t', header = TRUE) 
print(head(df))
df  <- df[ , c(input$lon, input$lat)]
bbox <- points_to_bbox(df, 
    proj_from = input$proj_from,
    proj_to = proj_to)

bbox <- as.vector(c(bbox$xmin, bbox$ymin, bbox$xmax, bbox$ymax))

    } else if (input$source == "box_coordinates") {
        if (is.null(proj_to)) {
     bbox <- as.vector(c(input$xmin, input$ymin, input$xmax, input$ymax))
       
     } else {
        df <- data.frame("lon" = c(input$xmin, input$xmin, input$xmax, input$xmax),
                        "lat" = c(input$ymin, input$ymax, input$ymin, input$ymax))
     
bbox <- points_to_bbox(df, 
    proj_from = input$proj_from,
    proj_to = proj_to)
bbox <- as.vector(c(bbox$xmin, bbox$ymin, bbox$xmax, bbox$ymax))
     }

    } else if (input$source == "shapefile") {
shp <- sf::st_read(input$path_shp)
bbox <- shp_to_bbox(shp, proj_from = input$proj_from, proj_to = proj_to)
bbox <- as.vector(c(bbox$xmin, bbox$ymin, bbox$xmax, bbox$ymax))

    } 

output <- list("bbox" =  bbox)
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))