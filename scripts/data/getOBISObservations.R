library(rjson)
library(sf)
library(robis)
library(dplyr)

input <- biab_inputs()
# load study area and transform to lat long
if (is.null(input$study_area)) {
        bbox_values <- unlist(input$bbox$bbox)
        print(bbox_values)

        study_area <- sf::st_as_sfc(
                sf::st_bbox(
                        c(
                                xmin = bbox_values[1],
                                ymin = bbox_values[2],
                                xmax = bbox_values[3],
                                ymax = bbox_values[4]
                        ),
                        crs = input$bbox$CRS$code
                )
        )
} else {
        study_area <- st_read(input$study_area)
}

if (input$bbox$CRS$code == "EPSG:4326") {
        study_area <- st_transform(study_area, crs = 4326)
}
# change to wkt
study_area_wkt <- st_as_text(st_geometry(study_area))
print(study_area_wkt)
species_list <- input$species_name

# Get OBIS data for all species
occurrences <- occurrence(
        scientificname = species_list, geometry = study_area_wkt, startdate = as.Date(input$start_date, format = "%Y-%m-%d"),
        enddate = as.Date(input$end_date, format = "%Y-%m-%d"), startdepth = input$min_depth, enddepth = input$max_depth
)
print(occurrences)
occurrences_path <- file.path(outputFolder, "occurrences.csv")
write.csv(occurrences, occurrences_path)
biab_output("occurrences", occurrences_path)
