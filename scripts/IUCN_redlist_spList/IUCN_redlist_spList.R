# Set session parameters ####
## Check and Install necessary libraries ####
packagesPrev<- installed.packages()[,"Package"] # Check and get a list of installed packages in this machine and R version
packagesNeed<- c("magrittr", "this.path", "rjson", "dplyr", "rredlist") # List of libraries required to run the code
new.packages <- packagesNeed[!(packagesNeed %in% packagesPrev)]; # Identify the libraries that are not installed
if(length(new.packages)) {install.packages(new.packages, binary=T, force=T, dependencies = F, repos= "https://packagemanager.posit.co/cran/__linux__/jammy/latest")} # Check and install the required packages that are not already installed

## Load libraries ###
packagesList<-list("magrittr") # Explicitly list packages needed that must be fully loaded in the environment. Functions from other libraries will be accessible via '::'.
lapply(packagesList, library, character.only = TRUE)  # Load explicitly listed libraries


# Set up the working environment ####

## Set output folder ####
# Option 1: Automatic definition of the `outputFolder` for the server environment from Bon in a Box. Designed for production use.
Sys.setenv(outputFolder = "/path/to/output/folder")

# Option 2: Manual definition of the 'outputFolder' when it is not automatically set by the server. Recommended for debugging purposes to facilitate script testing.
if ( (!exists("outputFolder"))  ) {outputFolder<- {x<- this.path::this.path();  file_prev<-  paste0(gsub("/scripts.*", "/output", x), gsub("^.*/scripts", "", x)  ); options<- tools::file_path_sans_ext(file_prev) %>% {c(., paste0(., ".R"), paste0(., "_R"))}; folder_out<- options %>% {.[file.exists(.)]} %>% {.[which.max(sapply(., function(info) file.info(info)$mtime))]}; folder_final<- list.files(folder_out, full.names = T) %>% {.[which.max(sapply(., function(info) file.info(info)$mtime))]} }}

## Set input folder ####
# Load input file from `outputFolder`
input <- rjson::fromJSON(file=file.path(outputFolder, "input.json")) # Load input file

# Adjust input values to correct and prevent errors in input paths
input<- lapply(input, function(y) lapply(y, function(x)  { if (!is.null(x) && length(x) > 0 && grepl("/", x) && !grepl("http://", x)  ) { sub("/output/.*", "/output", outputFolder) %>% dirname() %>%  file.path(x) %>% {gsub("//+", "/", .)}  } else{x} }) %>% unlist()) 



# Script body ####
token <- Sys.getenv("IUCN_TOKEN")
print(token)

## Load sp country ####
UICN_isocode <- rredlist::rl_countries(key = token)$results %>% dplyr::filter(country %in% input$country) %>% {.$isocode}
UICN_country <- rredlist::rl_sp_country(country= UICN_isocode, key = token)$result 
  
## Load sp taxonomic group ####
UICN_taxon <- rredlist::rl_comp_groups(group = input$taxonomic_group, key = token)$result


## Filter country list by taxonomic group ####
UICN_spList<- UICN_taxon %>% dplyr::filter(taxonid %in% UICN_country$taxonid)



# Write results ####  
UICN_spList_path<- file.path(outputFolder, paste0("UICN_spList", ".csv")) # Define the file path 
write.csv(UICN_spList, UICN_spList_path, row.names = F) # write result





# Outputing result to JSON ####

#Define final output list
output<- list(UICN_spList= UICN_spList_path)

# Write the output list to the 'output.json' file in JSON format
setwd(outputFolder)
jsonlite::write_json(output, "output.json", auto_unbox = TRUE, pretty = TRUE)