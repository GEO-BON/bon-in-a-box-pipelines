####### SInAS workflow: Integration and standardisation of alien species data ###########
##
## This script executes the SInAS workflow to standardise and integrate alien species 
## occurrence data. All required files and a manual can be found on GitHub:
## https://github.com/hseebens/SInAS
##
## Run the whole workflow by e.g. copy-pasting "source("runWorkflow.r")" into the R terminal.
##
## Manuela Gómez-Suárez, Hanno Seebens, Gießen, 02.07.2025
#########################################################################################

## --------------------------------------------------------------
## LOAD REQUIRED PACKAGES
## ------------------------------------------------------ 
library(rgbif) # for checking names, records and taxonomy; note: usage of rgbif may cause warnings like "Unknown or uninitalised column: " which is a bug. Can be ignored.
library(openxlsx)
library(data.table)
#library(tidyverse)
library(tidyr)
library(stringr)
library(stringi)
library(dplyr)


## ------------------------------------------------------
## SET INPUTS
## ------------------------------------------------------ 

input <- biab_inputs()
country_name <- input$country_name$country$englishName

griis <- read.csv("C:/Users/Samara/Desktop/bon-in-a-box-pipelines/output/IAS/P1_ChecklistDownload/download_checklist/24WCclDWWTOfF_TezBFTZE32-OPe/GRIIS_checklist.csv")
firstrecords <- read.csv("C:/Users/Samara/Desktop/bon-in-a-box-pipelines/output/IAS/P2_FirstRecordsData/standardise_data/MvoeUdjrbO9xW2gLxy9qcQhDgtHB/FirstRecords_cleaned.csv")

checklistType <- input$checklistType

# Add filter inputs here??

## ------------------------------------------------------
## SET DATE FOR CHECKLIST USE
## ------------------------------------------------------ 

DATE = Sys.Date() # Adjust to required checklist combined date


## ------------------------------------------------------
## LOAD REQUIRED DATASETS
## ------------------------------------------------------ 

## Skipping this step for now

## ------------------------------------------------------
## FILTER DATASETS AS NEEDED 
## ------------------------------------------------------ 

# Filter GRIIS data set 
GRIIS <- griis %>% 
  dplyr::filter(countryInCompendium == TRUE) %>% 
  dplyr::filter(checklistType == "national") %>% 
  dplyr::filter(checklistLevel != "Secondary") %>% 
  dplyr::filter(kingdom %in% c("PLANTAE","ANIMALIA")) %>% 
  dplyr::filter(habitat %in% c("TERRESTRIAL","FRESHWATER","FRESHWATER|BRACKISH",
                               "TERRESTRIAL|FRESHWATER", "MARINE|FRESHWATER|BRACKISH",
                               "TERRESTRIAL|BRACKISH", "TERRESTRIAL|FRESHWATER|BRACKISH",
                               "TERRESTRIAL|MARINE|FRESHWATER", "TERRESTRIAL|MARINE|BRACKISH",
                               "MARINE|FRESHWATER", "TERRESTRIAL|MARINE")) 

# Filter First Records data set 
FirstRecords <- firstrecords %>% 
  dplyr::filter(kingdom %in% c("PLANTAE","ANIMALIA")) %>% 
  dplyr::filter(habitat %in% c("TERRESTRIAL","FRESHWATER","FRESHWATER|BRACKISH",
                               "TERRESTRIAL|FRESHWATER", "MARINE|FRESHWATER|BRACKISH",
                               "TERRESTRIAL|BRACKISH", "TERRESTRIAL|FRESHWATER|BRACKISH",
                               "TERRESTRIAL|MARINE|FRESHWATER", "TERRESTRIAL|MARINE|BRACKISH",
                               "MARINE|FRESHWATER", "TERRESTRIAL|MARINE"))


## ------------------------------------------------------
## LOAD REQUIRED DATA
## ------------------------------------------------------ 

# Load file directory prom P1 to identify countries with data 
FileDirectory <- readxl::read_xlsx(file.path(workingDirectory,"P1_ChecklistDownload","Outputs","File_Directory.xlsx"))

# Load corrections table 
Corrections <- readxl::read_xlsx(file.path(workingDirectory, "Config", "AllCorrections_Updated.xlsx"))

## ------------------------------------------------------
## IDENTIFY FOCUS COUNTRIES
## ------------------------------------------------------ 

focusCountries <- GRIIS %>% 
  dplyr::filter(checklistType == "national") %>% # Removes all protected area checklists
  dplyr::filter(checklistLevel == "Primary") %>% # Removes all sub checklists within countries 
  dplyr::filter(countryInCompendium == TRUE) # Only includes countries with the GRIIS compendium 

 
## ------------------------------------------------------
## SET CORE NUMBER FOR PARALLEL PROCESSING
## ------------------------------------------------------ 

 setCores = 4 # Number of cores to use for parallel processing. If not possible set to 1.

## ------------------------------------------------------
## LOAD SInAS FUNCTIONS
## ------------------------------------------------------ 

################################################################################
## load functions #############################################################
# Ensure workingDirectory is set for IO
workingDirectory <- outputFolder
fxn_dir <- script_dir
source(file.path(fxn_dir, "PrepareDatasets.r")) # preparing example data sets as input files
source(file.path(fxn_dir, "StandardiseTaxonNames.R")) # standardising taxon names, requires GBIF connection, takes some time...
source(file.path(fxn_dir, "OverwriteTaxonNames_Updated.R")) # replace taxon names with user-defined ones
source(file.path(fxn_dir, "StandardiseLocationNames.R")) # standardising location names
source(file.path(fxn_dir, "StandardiseTerms.R")) # standardising location names
source(file.path(fxn_dir, "GeteventDate.R")) # standardising location names
source(file.path(fxn_dir, "MergeDatabses.R")) # combine data sets (note: file name has spelling in repo)
# CheckGBIFTax is optional — source if present in repo
check_gbif_path <- file.path(fxn_dir, "CheckGBIFTax.R")
if (file.exists(check_gbif_path)) source(check_gbif_path)
source(file.path(fxn_dir, "ParallelCheckGBIFTax.R")) #function to check taxon names using GBIF taxonomy
################################################################################

## ------------------------------------------------------
## SET OUPUT FILE NAMES
## ------------------------------------------------------ 

## option for storing the intermediate and final output
outputfilename <- Country # name of final output file

version <- "1.0" # which version of the database are you going to produce? this will be attached to the end of 'outputfilename'

output <- T # shall intermediate results be stored to disk? (may overwrite existing files!)


## ------------------------------------------------------
## RUN WORKFLOW
## ------------------------------------------------------ 

################################################################################
######## Load data set table ###################################################

# Create data sets for country and set input variables 
cat("\n Step 1 Preparing data sets \n")
## Prepare datasets (use local helper in repo)
source(file.path(fxn_dir, "prepareData_update.R"))

## load databases, extract required information and harmonise taxon names...
cat("\n Step 1 Preparation of provided data sets \n")
FileInfo <- PrepareDatasets(datasets_in = datasets)

## load databases, extract required information and harmonise taxon names...
cat("\n Step 2 Standardisation of terminology \n")
StandardiseTerms(FileInfo)

## harmonise location names
cat("\n Step 3 Standardisation of location names \n")
StandardiseLocationNames(FileInfo)

## Check if any locations are missing and update locations data set (local QC helper)
missing_qc_path <- file.path(fxn_dir, "missingLocationsQualityControl.R")
if (file.exists(missing_qc_path)) {
  source(missing_qc_path)
} else {
  warning("missingLocationsQualityControl.R not found in repo; skipping missing-locations QC")
}

# ## Re run standardise location names and check
# StandardiseLocationNames(FileInfo)
# source(file.path(workingDirectory,"P3_SInASworkflow","QualityControl","R","missingLocationsQualityControl.R"))

## load databases, extract required information and harmonise taxon names...
cat("\n Step 4 Standardisation of taxon names \n")
StandardiseTaxonNames(FileInfo) # FULL LIST TAKES: GRIIS - 50 mins and First Records - 2hr 40 mins

## Run manual check on names that did not harmonise
taxa_qc_path <- file.path(fxn_dir, "taxaHarmonisationQualityControl.R")
if (file.exists(taxa_qc_path)) {
  source(taxa_qc_path)
} else {
  warning("taxaHarmonisationQualityControl.R not found in repo; skipping taxa harmonisation QC")
}

## Overwrite taxon names using user-defined taxon names 
OverwriteTaxonNames(FileInfo) # user-defined taxon names

## standardise first records....
cat("\n Step 5 Standardisation of eventDate \n")
GeteventDate(FileInfo)

## merge databases...
cat("\n Step 6 Merging databases \n")
MergeDatabases(FileInfo,version,outputfilename,output)

# Register merged output with BON-in-a-Box if present
merged_path <- file.path(workingDirectory, "Output", "Merged", paste0(outputfilename, "_", version, ".csv"))
if (file.exists(merged_path) && exists("biab_output")) {
  biab_output("integrated_data", merged_path)
  biab_info(paste("Wrote merged file:", merged_path))
} else {
  if (!file.exists(merged_path)) warning("Expected merged output not found: ", merged_path)
}

