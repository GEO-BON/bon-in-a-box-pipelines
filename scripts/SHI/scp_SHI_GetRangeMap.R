#-------------------------------------------------------------------------------
# This script downloads the range map according to the expert source chosen
#-------------------------------------------------------------------------------
# Script location can be used to access other scripts

print(Sys.getenv("SCRIPT_LOCATION"))
packages <- c("rjson","dplyr","tidyr","purrr","sf","stringr")

new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

lapply(packages,require,character.only=T)

path_script <- Sys.getenv("SCRIPT_LOCATION")

input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

source(file.path(path_script,"SHI/funGet_range_maps.R"), echo=TRUE)

# Inputs -----------------------------------------------------------------------
# Define species
sp <- str_to_sentence(input$species)

# Define source of expert range maps
expert_source <- input$expert_source

# Step 1.1 ---------------------------------------------------------------------
source_range_maps <- data.frame(expert_source=expert_source ,
                                species_name = sp) |>
  dplyr::mutate(function_name=case_when(
    expert_source=="IUCN"~ "get_iucn_range_map",
    expert_source=="MOL"~ "get_mol_range_map",
    expert_source=="QC" ~ "get_qc_range_map"
  ),
  species_path= case_when(
    expert_source=="IUCN"~ sp,
    expert_source=="MOL"~ paste0(sp,"_mol"),
    expert_source=="QC" ~ paste0(sp,"_qc")
  ))

with(source_range_maps, do.call(function_name,args = list(species_name=species_name)))

file <- paste0(source_range_maps$species_path,'_range.gpkg')

if(file.exists(file)){
  sf_range_map <- st_read(file)
}else{
  path_to_range_map <- NULL
  cat("========== No range map available for ", sp ,"at the ", expert_source , " expert source database ==========")
}

if (!dir.exists(file.path(outputFolder,sp))){
  dir.create(file.path(outputFolder,sp))
}else{
  print("dir exists")
}

path_to_range_map <- file.path(outputFolder, sp, file)
sf::st_write(sf_range_map, path_to_range_map, append = FALSE  )

# Outputing result to JSON -----------------------------------------------------
output <- list("sf_range_map" = path_to_range_map )

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder, "output.json"))