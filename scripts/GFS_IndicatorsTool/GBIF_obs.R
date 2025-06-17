library(rgbif)
library(dplyr)
library(CoordinateCleaner)
library(rjson)
library(countrycode)



## Load the input from Bon in a box
input <- fromJSON(file=file.path(outputFolder, "input.json"))
species <- input$species
countries <- input$countries
year_start <- input$start_year
year_end <- input$end_year
coordinate_precision <- input$coordinate_precision
coordinate_uncertainty <- input$coordinate_uncertainty
bbox <- input$bbox


print("########COUNTRY########")
print(countries)



taxonkey <- name_backbone(species)$usageKey




if (!is.null(countries) && length(countries) > 0) {# Check if country_predicates has more than one element
  countries <- countrycode(countries, "country.name", "iso2c")
  country_predicates <- lapply(countries, function(c) pred("country", c))
  if (length(country_predicates) > 1) {
    combined_country_predicates <- do.call(pred_or, country_predicates)
  } else if (length(country_predicates) == 1) {
    combined_country_predicates <- country_predicates[[1]]
  } else {
    stop("No valid country predicates provided.")
  }
  
  # Use the combined_country_predicates in the occ_download call
  gbif_download <- occ_download(
    pred("taxonKey", taxonkey),
    pred("hasCoordinate", TRUE),
    pred("hasGeospatialIssue", FALSE),
    combined_country_predicates,  # Use the combined predicates
    pred_gte("year", year_start), # Year >= start_year
    pred_lte("year", year_end),   # Year <= end_year
    format = "SIMPLE_CSV"
  )
} else {
  bbox_to_wkt <- function(bbox) {
    paste0("POLYGON((", 
           bbox[1], " ", bbox[2], ", ",  # min_lon, min_lat
           bbox[3], " ", bbox[2], ", ",  # max_lon, min_lat
           bbox[3], " ", bbox[4], ", ",  # max_lon, max_lat
           bbox[1], " ", bbox[4], ", ",  # min_lon, max_lat
           bbox[1], " ", bbox[2], "))")  # Close the polygon
  }
  gbif_download <- occ_download(
    pred("taxonKey", taxonkey),
    pred("hasCoordinate", TRUE),
    pred("hasGeospatialIssue", FALSE),
    pred_within(bbox_to_wkt(bbox)),  # Use transformed bbox
    pred_gte("year", year_start),
    pred_lte("year", year_end),
    format = "SIMPLE_CSV"
  )
}



occ_download_wait(gbif_download) 
# filtering pipeline  
gbif_data<-gbif_download %>%
  occ_download_get() %>%
  occ_download_import() %>%
  setNames(tolower(names(.))) %>% # set lowercase column names to work with CoordinateCleaner
  filter(occurrencestatus  == "PRESENT") %>%
  filter(!basisofrecord %in% c("FOSSIL_SPECIMEN","LIVING_SPECIMEN")) %>%
  filter(year >= 1900) %>% 
  filter(coordinateprecision < 0.01 | is.na(coordinateprecision)) %>% 
  filter(coordinateuncertaintyinmeters < 10000 | is.na(coordinateuncertaintyinmeters)) %>%
  filter(!coordinateuncertaintyinmeters %in% c(301,3036,999,9999)) %>% 
  filter(!decimallatitude == 0 | !decimallongitude == 0) %>%
  # cc_cen(buffer = 2000) %>% # remove country centroids within 2km 
  # cc_cap(buffer = 2000) %>% # remove capitals centroids within 2km
  # cc_inst(buffer = 2000) %>% # remove zoo and herbaria within 2km 
  # cc_sea() %>% # remove from ocean 
  distinct(decimallongitude,decimallatitude,specieskey,datasetkey, .keep_all = TRUE) # look at results of pipeline
path = file.path(outputFolder, 'GBIF_obs.csv')
write.table(gbif_data, path, append = FALSE, , sep = "\t", quote=FALSE)


### Make the output accesible to Bon in a Box
output <- list("observation_data" = path)

### return output
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder, "output.json"))


