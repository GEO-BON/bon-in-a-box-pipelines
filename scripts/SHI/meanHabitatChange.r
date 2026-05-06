#-------------------------------------------------------------------------------
# This script takes all the species habitat maps and gets the mean habitat
#-------------------------------------------------------------------------------
# Script location can be used to access other scripts
print(Sys.getenv("SCRIPT_LOCATION"))
options(timeout = max(60000000, getOption("timeout")))

packages <- list("dplyr", "purrr", "readr", "ggplot2", "rjson")

lapply(packages, library, character.only = TRUE)

path_script <- Sys.getenv("SCRIPT_LOCATION")

input <- biab_inputs()
print("Inputs: ")
print(input)





#-------------------------------------------------------------------------------
# Outputing result
biab_output("df_shi", path_SHI)
biab_output("img_shi_timeseries", path_img_SHI_timeseries)
biab_output("img_w_shi_timeseries", path_img_W_SHI_timeseries)
biab_output("img_SubScores_boxplots", path_img_SubScores_boxplots)