library(sf)
library(rjson)
library(dplyr)
library(wdpar)

# Add inputs
input <- biab_inputs()

# Get polygon for study area

# Read in polygon of study area
if(is.null(input$study_area_polygon)){
  biab_error_stop("No study area polygon found. Please provide a geopackage of the study area. To pull country or region 
  shapefiles, connect this script to the 'Get country polygon' script")
  }

study_area <- input$study_area_polygon
study_area <- sf::st_read(study_area, type=3, promote_to_multi=FALSE) 
study_area <- st_transform(study_area, crs=input$crs)

# Read in wdpa data
protected_areas <- sf::st_read(input$protected_area_file)

# transform
protected_areas <- st_transform(protected_areas, crs=input$crs)

## Clean data
print("cleaning data")

print("Including areas based on status")

protected_areas <- protected_areas %>%
  filter(sapply(legal_status, function(x) any(grepl(input$exclude_status, x, ignore.case = TRUE))))

if (input$exclude_unesco==TRUE){
print("Removing UNESCO biosphere reserves")
  protected_areas <- protected_areas %>% filter(grepl("UNESCO-MAB Biosphere Reserve", designation))
}

# Fixing geometries

## Crop data by study area
print("Cropping data by study area")
protected_areas <- st_intersection(protected_areas, study_area)




















# # Pull data from wdpa
# if (Sys.getenv("WDPA_KEY") ==''){ # error if API key not found
#   biab_error_stop("WDPA key not found. Please make sure you have an API access key in your 'runner.env' file. 
#   To register for one, go to https://api.protectedplanet.net/request")
# }

# countries <- get_countries(key="WDPA_KEY")

# country_code <- countries %>% filter(country_name==input$country)
# print(country_code)

### REMOVE INVALID GEOMETRIES
protected_areas <- protected_areas[!st_geometry_type(protected_areas)%in%c("LINESTRING", "POINT", "MULTILINESTRING"),]

#print("Pulling data from WDPA")
# get protected areas
# If user selects WDPA or both, load WDPA data
# if(input$pa_input_type == "WDPA" | input$pa_input_type =="Both"){
#   protected_areass_wdpa <- get_wdpa(country_code$country_iso3, path=outputFolder, key="WDPA_KEY")
#   print(class(protected_areass_wdpa))
#   # Crop by region if user specifies one
#   # transform to crs of interest
#   protected_areass_wdpa <- st_transform(protected_areass_wdpa, crs=input$crs)
#   protected_areass_wdpa <- st_make_valid(protected_areass_wdpa)
#   if(!is.null(input$region)){
#    print("Cropping by region")
#     protected_areass_wdpa <- st_intersection(protected_areass_wdpa, study_area)
#   }
#   # project
#   protected_areass_wdpa <- protected_areass_wdpa %>% st_transform(input$crs)
#   protected_areass_wdpa <- protected_areass_wdpa %>% rename(STATUS_YR = legal_status_updated)
#   protected_areass_wdpa$STATUS_YR <- lubridate::parse_date_time(protected_areass_wdpa$STATUS_YR, orders=c("ymd", "mdy", "dmy", "y"))
#   protected_areass_wdpa$STATUS_YR <- lubridate::year(protected_areass_wdpa$STATUS_YR)
# } 

# # if user selects user input or both, load user data
# if (input$pa_input_type == "User input" | input$pa_input_type =="Both"){
#   # read in file
#   protected_areass_user <- st_read(input$protected_areas_file)
#   # reproject
#   protected_areass_user <- protected_areass_user %>% st_transform(input$crs)
#   # error if date column name is not correct
#   if(!input$date_column %in% colnames(protected_areass_user)){
#   biab_error_stop("The column name for the date of establishment of the protected area was not correct.")
#   }
# # make sure date is in right format and extract year
#   protected_areass_user <- protected_areass_user %>% rename(STATUS_YR = input$date_column_name)
#   # extract year
#   protected_areass_user$STATUS_YR <- lubridate::parse_date_time(protected_areass_user$STATUS_YR, orders=c("ymd", "mdy", "dmy", "y"))
#   protected_areass_user$STATUS_YR <- lubridate::year(protected_areass_user$STATUS_YR)
# }

# # if user selects user input, use only that data
# if(input$pa_input_type == "User input"){
#   protected_areass <- protected_areass_user
# }

# # if user selects both, combine the data
# if(input$pa_input_type == "Both"){
#   # combine if both
#   protected_areass <- dplyr::bind_rows(protected_areass_wdpa[,c("STATUS_YR", "geom")], protected_areass_user[,c("STATUS_YR", "geom")])
# } else if (input$pa_input_type == "User input") {
#   protected_areass <- protected_areass_user
# } else {
#   protected_areass <- protected_areass_wdpa
# }

# print(str(protected_areass))

# print("Protected areas downloaded")
# # validte geometery
# protected_areass <- st_make_valid(protected_areass)

# if(nrow(protected_areass)==0){
#   stop("Protected area polygon does not exist. Check spelling of country and state names. Check if region contains protected areas")
# }  # stop if object is empty
# print("Protected areas downloaded")

# # output number protected areas
# number_pas <- nrow(protected_areass)
# biab_output("number_pas", number_pas)

# print("done")

# output protected areas
protected_areas_path <- file.path(outputFolder, "protected_areas.gpkg")
sf::st_write(protected_areas, protected_areas_path, delete_dsn = T)
biab_output("protected_areas", protected_areas_path)
