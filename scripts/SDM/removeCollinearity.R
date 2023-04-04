

## Install required packages
packages <- c("terra", "rjson", "raster", "stars", "dplyr", "CoordinateCleaner", "lubridate", "rgdal", "remotes", "RCurl")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
Sys.setenv("R_REMOTES_NO_ERRORS_FROM_WARNINGS" = "true")
library("devtools")
if (!"stacatalogue" %in% installed.packages()[,"Package"]) devtools::install_github("ReseauBiodiversiteQuebec/stac-catalogue")
if (!"gdalcubes" %in% installed.packages()[,"Package"]) devtools::install_github("appelmar/gdalcubes_R")

## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/removeCollinearityFunc.R", sep = "/"))
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/sdmUtils.R", sep = "/"))

#install.packages("gdalcubes")
library("terra")
library("rjson")
library("raster")
library("dplyr")
library("stacatalogue")
library("gdalcubes")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


rasters <- input$rasters
method <- input$method_cor_vif
cutoff_cor <- input$cutoff_cor
  
if (!method %in% c("none", "vif.cor", "vif.step", "pearson", "spearman", "kendall")) {
  stop("method must be vif.cor, vif.step, pearson, spearman, or kendall")
}
  
if (method %in% c("vif.cor", "pearson", "spearman", "kendall") && is.null(cutoff_cor)) {
  cutoff_cor <- 0.8
}
rasts<-c()
names_file<-list()
for (ra in rasters){
    thisras <- terra::rast(ra)
    rasts <- c(rasts,thisras)
    names_file[[names(thisras)]]<-ra
}
rasts <- rast(rasts)

env_df <- sample_spatial_obj(rasts, nb_points = input$nb_sample)
nc_names <-detect_collinearity(env_df = env_df,
                method = method,
                method_cor_vif = input$method_cor_vif,
                cutoff_cor = cutoff_cor,
                cutoff_vif = input$cutoff_vif,
                export = F,
                title_export = "Correlation plot of environmental variables.",
                path = getwd()) 
print('Selected variables:')
print(nc_names)

output <- list("rasters_selected" = as.vector(unlist(names_file[nc_names])))
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))


    
