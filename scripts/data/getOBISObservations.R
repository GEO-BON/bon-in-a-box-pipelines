library(rjson)
library(sf)
library(robis)
library(dplyr)

input <- biab_inputs()
# load study area and transform to lat long
study_area <- st_read(input$study_area) %>% st_transform("EPSG:4326")
# change to wkt
#study_area_wkt <- st_as_text(study_area)

species_list <- input$species_name

# Get OBIS data for all species
occurrences <- occurrence(scientificname = input$species_name, geometry=input$study_area, startdate=as.Date(input$start_date, format="%Y-%m-%d"), 
        enddate=as.Date(input$end_date, format="%Y-%m-%d"), startdepth=input$min_depth, enddepth=input$max_depth) 

occurrences_path <- file.path(outputFolder, "occurrences.csv")
write.csv(occurrences, occurrences_path)
biab_output("occurrences", occurrences_path)