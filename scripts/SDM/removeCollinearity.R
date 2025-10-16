## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/removeCollinearityFunc.R", sep = "/"))

## Load required packages
packages_list <- list("terra", "rjson", "raster", "dplyr", "gdalcubes")

lapply(packages_list, library, character.only = TRUE)

library("terra")
library("rjson")
library("raster")
library("dplyr")
library("gdalcubes")

input <- biab_inputs()
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
rasts <- c()
names_file <- list()
for (ra in rasters) {
  thisras <- terra::rast(ra)
  rasts <- c(rasts, thisras)
  names_file[[names(thisras)]] <- ra
}
rasts <- rast(rasts)

rasts
env_df <- sample_spatial_obj(rasts, nb_points = input$nb_sample)
nc_names <- detect_collinearity(
  env_df = env_df,
  method = method,
  method_cor_vif = input$method_cor_vif,
  cutoff_cor = cutoff_cor,
  cutoff_vif = input$cutoff_vif,
  export = F,
  title_export = "Correlation plot of environmental variables.",
  path = getwd()
)
print("Selected variables:")
print(nc_names)

biab_output("rasters_selected", as.vector(unlist(names_file[nc_names])))
