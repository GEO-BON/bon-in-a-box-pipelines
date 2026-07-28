## ------------------------------------------------------
## Script name: IAS Rate Modelling with Alien package
##
## Purpose of script: This script runs the workflow for modelling the IAS rate for a country
## using the alien package, with options for the naive model, S&C model, and covariate S&C model
##
## Author: Rachel Mason
##
## Date Created: 2025-10-07
## ------------------------------------------------------
## ------------------------------------------------------


## ------------------------------------------------------
## SET INPUT AND OUTPUT PATHS
## ------------------------------------------------------ 

# Set working directory 
workingDirectory <- "C:/Users/rmas0011/OneDrive - Monash University/McGeoch Research Group - IAS Indicator Project/1 - Global/BON in a Box Collaboration/Workflow Code"


# Set sub folder name/path for current phase (i.e. which "P" folder)
subDirectory <- "P6_DataModelling"

## ------------------------------------------------------
## SET COUNTRY
## ------------------------------------------------------ 

# Set Country of Interest 
# Countries <- c("NOR") #Must be ISO3

Countries <- c("AUS")

## ------------------------------------------------------
## RUN MODELS AND EXPORT TABLES + PLOTS OF MODEL RESULTS
## ------------------------------------------------------ 

source(file.path(workingDirectory,subDirectory,"R","ModelData.R"))

view(out)

## ---------------------------------------------------------------------------
## OPTIONAL - OVERWRITE SUMMARY FILE OF ALL MODEL OUTPUTS
## --------------------------------------------------------------------------- 

#only run this line if you have modelled ALL countries in above loop
write_csv(out, file.path(workingDirectory,subDirectory,"Output",paste0("ModelOutputs.csv")))



