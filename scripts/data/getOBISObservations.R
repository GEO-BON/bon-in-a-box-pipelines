library(rjson)
library(sf)
library(robis)
library(dplyr)

input <- biab_inputs()
# load bounding box of input
bbox_values <- unlist(input$bbox$bbox)
print(bbox_values)

bbox <- sf::st_as_sfc(
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


if (!input$bbox$CRS$code == "EPSG:4326") {
        bbox <- st_transform(bbox, crs = 4326)
}
# change to wkt
bbox_wkt <- st_as_text(st_geometry(bbox))
print(bbox_wkt)
species_list <- input$species_name

# Get OBIS data for all species
occurrences <- occurrence(
        scientificname = species_list, geometry = bbox_wkt, startdate = as.Date(input$start_date, format = "%Y-%m-%d"),
        enddate = as.Date(input$end_date, format = "%Y-%m-%d"), startdepth = input$min_depth, enddepth = input$max_depth
)

# If there is a study area input, crop
if (!is.null(input$study_area)) {
        study_area <- st_read(input$study_area)
        
        if (input$bbox$CRS$code == "EPSG:4326") {
                study_area <- st_transform(study_area, crs = 4326)
        }

        occ_sf <- occurrences %>%
                # Remove records with missing or 0,0 coordinates
                filter(
                        !is.na(decimalLongitude),
                        !is.na(decimalLatitude),
                        decimalLongitude != 0,
                        decimalLatitude != 0
                ) %>% rename (longitude = decimalLongitude, latitude = decimalLatitude) %>%
                st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)
        occ_sf_cropped <- st_filter(occ_sf, study_area)
        occurrences <- st_drop_geometry(occ_sf_cropped)
}

occurrences_path <- file.path(outputFolder, "occurrences.csv")
write.csv(occurrences, occurrences_path)
biab_output("occurrences", occurrences_path)
