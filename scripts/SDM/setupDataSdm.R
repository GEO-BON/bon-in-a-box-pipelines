## Load required packages
packages_list <- list("terra", "rjson", "raster", "dplyr", "gdalcubes", "ENMeval")

lapply(packages_list, library, character.only = TRUE)

## Load functions
source(paste(Sys.getenv("SCRIPT_LOCATION"), "SDM/setupDataSdmFunc.R", sep = "/"))

input <- biab_inputs()
print("Inputs: ")
print(input)

presence <- read.table(file = input$presence, sep = "\t", header = TRUE)
background <- read.table(file = input$background, sep = "\t", header = TRUE)
predictors <- terra::rast(unlist(input$predictors))

presence_bg_vals <- setup_presence_background(
  presence = presence,
  background = background,
  predictors = predictors,
  partition_type = input$partition_type,
  runs_n = input$runs_n,
  boot_proportion = input$boot_proportion,
  cv_partitions = input$cv_partitions,
  seed = NULL
)

presence_background.output <- file.path(outputFolder, "presence_background.tsv")

write.table(presence_bg_vals, presence_background.output,
  append = F, row.names = F, col.names = T, sep = "\t"
)

biab_output("presence_background", presence_background.output)
