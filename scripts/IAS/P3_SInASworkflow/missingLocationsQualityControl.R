## ------------------------------------------------------
## Script name: Post SInAS workflow Missing Locations Quality Control 
##
## Purpose of script: This script allows the user ot add missing locations before continuing with the SInAS workflow
##
## Author: Saxbee Affleck
##
## Date Created: 2025-08-27
## ------------------------------------------------------
## ------------------------------------------------------


## ------------------------------------------------------
## LOAD MISSING LOCATIONS
## ------------------------------------------------------ 

if(file.exists(file.path(workingDirectory,subDirectory,"Output","Check","Missing_Locations_GRIIS.csv"))) {
  missingLocations_GRIIS <- data.table::fread(file.path(workingDirectory,subDirectory,"Output","Check","Missing_Locations_GRIIS.csv"), sep = NULL, col.names = "location") #%>% 
    #dplyr::mutate(location = gsub("\"","",location))
} else {missingLocations_GRIIS <- NULL}

if(file.exists(file.path(workingDirectory,subDirectory,"Output","Check","Missing_Locations_FirstRecords.csv"))) {
  missingLocations_FirstRecords <- data.table::fread(file.path(workingDirectory,subDirectory,"Output","Check","Missing_Locations_FirstRecords.csv"), sep = NULL, col.names = "location") #%>% 
    #dplyr::mutate(location = gsub("\"","",location))
} else {missingLocations_FirstRecords <- NULL}

missingLocations <- dplyr::bind_rows(missingLocations_GRIIS,missingLocations_FirstRecords)

if(nrow(missingLocations)>0) {
  
  ## ------------------------------------------------------
  ## CONFIGURE LOCATION NAMES
  ## ------------------------------------------------------ 
  
  # Keep sheets for save full set later (read from repo `config_dir`)
  Locations2 <- readxl::read_xlsx(file.path(config_dir, "AllLocations.xlsx"), sheet = 2)
  Locations3 <- readxl::read_xlsx(file.path(config_dir, "AllLocations.xlsx"), sheet = 3)
  
  # load location data 
  Locations <- readxl::read_xlsx(file.path(config_dir, "AllLocations.xlsx"), sheet = 1)
  
  # Loop through each location 
  for(x in 1:nrow(missingLocations)) {
    
    repeat {
      Row = missingLocations$location[x]
      
      message("-------------------------------------------------------------------")
      message("Missing location:")
      print(Row)
      
      message("Here are exists locations:")
      locationInfo <- Locations %>% dplyr::filter(ISO3 == Country) %>%
        dplyr::select(locationID, ISO3, location, location_var) %>%
        dplyr::distinct(location, .keep_all = TRUE)
      print(locationInfo)
      
      message("Which locationID would you like to add the missing name to:")
      ID <- readline("Enter Location ID:")
      
      # Add line to check if a repeat is needed
      message("Have you entered the details correctly?")
      message("1: Yes")
      message("2: No/Repeat")
      BREAK <- readline("Select response:")
      
      if (BREAK == "1") {
        
        # Add alternative names for places to existing locations
        Locations <- Locations %>%
          dplyr::mutate(
            location_var =
              dplyr::case_when(
                locationID == as.numeric(ID) ~ paste(Row, location_var, sep = ";"),
                TRUE ~ as.character(location_var)
              )
          )
        
        
        break # Exit the loop and move to next entry
      }
      
    }
    
  }
  
  # Save updated file back into the BIAB output Config so changes are captured
  out_config_dir <- file.path(workingDirectory, "Config")
  if (!dir.exists(out_config_dir)) dir.create(out_config_dir, recursive = TRUE)
  writexl::write_xlsx(list("location_stateProvince" = Locations, "location" = Locations2, "stateProvince" = Locations3),
                      file.path(out_config_dir, "AllLocations.xlsx"))
  
} else {
  
  message("All locations have been standardised")
  
}

