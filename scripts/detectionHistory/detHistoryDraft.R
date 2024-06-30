#### Load required packages - libraries to run the script ####

# Install necessary libraries - packages  
packagesPrev<- installed.packages()[,"Package"] # Check and get a list of installed packages in this machine and R version
packagesNeed<- c("magrittr", "terra", "raster", "sf", "pbapply", "this.path", "rjson", "lubridate", "camptrapR") # Define the list of required packages to run the script
new.packages <- packagesNeed[!(packagesNeed %in% packagesPrev)]; if(length(new.packages)) {install.packages(new.packages, binary=T)} # Check and install required packages that are not previously installed

# Load libraries
packagesList<-list("magrittr", "terra") # Explicitly list the required packages throughout the entire routine. Explicitly listing the required packages throughout the routine ensures that only the necessary packages are listed. Unlike 'packagesNeed', this list includes packages with functions that cannot be directly called using the '::' syntax. By using '::', specific functions or objects from a package can be accessed directly without loading the entire package. Loading an entire package involves loading all the functions and objects 
lapply(packagesList, library, character.only = TRUE)  # Load libraries - packages  


#### Set enviroment variables ####




input <- list(
  "speciesCol"="scientificName",
  "species"="Cuniculus paca",
  "stationCol"="ID_grid",
  "evendateCol"="eventDate",
  "eventTimeCol"="eventTime",
  "cameraCol"="Cam.Site",
  "setupCol"="Instal.Date",
  "retrievalCol"="Last.eventDate",
  "min_NAs"=7,
  "data"= "C:/Repositories/biab-2.0/scripts/detectionHistory/input/vars_dataset.csv")




####  Script body ####
#Read data input
join_sp <- data.table::fread(input$data) %>% as.data.frame()
sp_prior <- input$sp_prior

# Add a column with date and time ####
join_sp_data<- join_sp
join_sp_data[, input$evendateCol]<- lubridate::parse_date_time(x = join_sp_data[, input$evendateCol], order = c("dmy", "Ymd","dmY"))
join_sp_data[, input$setupCol]<- lubridate::parse_date_time(x = join_sp_data[, input$setupCol], order = c("dmy", "Ymd","dmY"))
join_sp_data[, input$retrievalCol]<- lubridate::parse_date_time(x = join_sp_data[, input$retrievalCol], order = c("dmy", "Ymd","dmY"))
join_sp_data[, "collapse_hour"]<-  as.POSIXct(join_sp_data[, input$eventTimeCol], format = "%H:%M:%S") %>% round.POSIXt(units = "hours") %>% format("%H") %>% as.numeric()



join_sp_noNA<- join_sp_data %>% dplyr::filter(!is.na(.[, input$evendateCol]), !is.na(.[, input$evendateCol]))
join_records <- join_sp_noNA %>% dplyr::mutate(DateTimeOriginal = paste(.[,input$evendateCol], .[,input$eventTimeCol]))

join_records$DateTimeOriginal <- as.POSIXlt(join_records$DateTimeOriginal)
sp_covars <- join_records %>%
  dplyr::select( as.character(unlist(input[c("setupCol", "retrievalCol", "stationCol", "cameraCol" )])) ) %>%
  na.omit()  %>% dplyr::distinct()

# join_records<- join_records %>% dplyr::select("Instal.Date" ,input$retrievalCol,   )


# Create camera operation name of stations
cam_op <- camtrapR::cameraOperation(CTtable = sp_covars,
                                    setupCol = input$setupCol,
                                    retrievalCol = input$retrievalCol,
                                    stationCol = input$stationCol,
                                    cameraCol = input$cameraCol,
                                    byCamera = FALSE,
                                    allCamsOn = TRUE,
                                    camerasIndependent = FALSE,
                                    hasProblems  = FALSE)


# Show all unique entries of specie cam.sites that are not in the covars sites, and delete it
not_in_sprec <- unique(join_records[, input$cameraCol])[!unique(join_records[, input$cameraCol]) %in% sp_covars[, input$cameraCol]]
sp_rec2 <- join_records[ !join_records[, input$cameraCol] %in% not_in_sprec ,]

# Create detection history for one specie
DH_sp <- camtrapR::detectionHistory (recordTable = sp_rec2,
                                     species = input$species,
                                     camOp = cam_op,
                                     stationCol = input$stationCol,
                                     speciesCol = input$speciesCol,
                                     recordDateTimeCol = "DateTimeOriginal",
                                     recordDateTimeFormat  = "%Y-%m-%d%H:%M:%S",
                                     occasionLength = 6,  #change to colaps diferent dates
                                     day1 = "station",  #first day of survey; if we want to specify a date put in "survey"
                                     datesAsOccasionNames = F,
                                     includeEffort = F, #careful if trapping effort is thought to influence detection probability, it can be returned by setting includeEffort = TRUE.
                                     scaleEffort = F)            #maybe wise using T, explore later


# Clean
DH_sp_data<- DH_sp$detection_history %>% as.data.frame.matrix() %>%
  dplyr::mutate(sum_det= rowSums(., na.rm=T), na= rowSums(is.na(.))) %>%
  tibble::rownames_to_column(input$stationCol)

# Delete sites with only NA (so no survey)
DH_sp_clean <-   DH_sp_data %>% dplyr::filter(na <= input$min_NAs) %>% 
  dplyr::select(-c("sum_det", "na")) 

DH_sp_adjust<- DH_sp_clean %>% tibble::column_to_rownames(input$stationCol) 

# Delete from covars those that were NA
sp_filter_clean <- join_records[ join_records[, input$stationCol] %in% rownames(DH_sp_adjust),]

#Join DH matrix and covariables
join_DH <- plyr::join_all(list(DH_sp_clean, sp_filter_clean), by =  input$stationCol, match = "first" )

library(unmarked)

umf = unmarkedFrameOccu(y = DH_sp_adjust, siteCovs = dplyr::select(join_DH, c("Dis_forest", "chelsa_clim_bio1", "chelsa_clim_bio2")),
                        obsCovs = NULL)

# pivot_wider
umf2<- umf; umf2@obsCovs<- dplyr::select(join_DH, c("ID_grid", "collapse_hour")) %>%  tibble::column_to_rownames("ID_grid")

formula_occ<- as.formula( paste0("~ ", paste0("collapse_hour", collapse = " + "), " ~ ", paste0(c("chelsa_clim_bio1"), collapse = " + ")) )
occ_model <- occu( formula_occ, umf2)  # fit a model

# problemas con la convergencia del modelo pueden ser causados por la multicolinealidad entre las covariables, la sobreparametrización debido a un exceso de variables en relación con la cantidad de datos disponibles, o la insuficiencia de variabilidad en los datos, lo cual dificulta la estimación precisa de los parámetros del modelo.
occ_dredge <- MuMIn::dredge(occ_model)





















## Write results ####
DH_sp_clean_path<- file.path(outputFolder, paste0("DH_sp_clean", ".csv")) # Define the file path
write.csv(DH_sp_clean, DH_sp_clean) # write result
DH_sp_clean_path<- file.path(outputFolder, paste0("DH_sp_clean", ".csv")) # Define the file path
write.csv(DH_sp_clean, DH_sp_clean_path) # write result
sp_filter_clean_path<- file.path(outputFolder, paste0("sp_filter_clean", ".csv")) # Define the file path
write.csv(sp_filter_clean, sp_filter_clean_path) # write result
join_DH_path<- file.path(outputFolder, paste0("join_DH", ".csv")) # Define the file path
write.csv(join_DH, join_DH_path) # write result







aa<- dplyr::select(sp_filter_clean, c("ID_grid", "Dis_forest", "chelsa_clim_bio1", "chelsa_clim_bio2"))[1:10,]
aa$Dis_forest<- c(1,1,1,2,2,2,2,3,3,3)
aa$ID_grid[3:4]<-1 

# pivot_wider
bb<- dplyr::select(join_DH, c("ID_grid", "Dis_forest"))


nn <- bb %>% group_by(ID_grid, Dis_forest) %>% mutate(index = row_number()) %>% ungroup() %>% 
  pivot_wider(names_from = Dis_forest, values_from = Dis_forest, names_prefix = "Dis_forest.", values_fill = NA) %>%
  select(-index)