#-------------------------------------------------------------------------------
# This script downloads the range map according to the expert source chosen
#-------------------------------------------------------------------------------
# Script location can be used to access other scripts

print(Sys.getenv("SCRIPT_LOCATION"))
#packages <- c("rjson","dplyr","tidyr","purrr","sf","stringr")

#new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
#if(length(new.packages)) install.packages(new.packages)

#lapply(packages,require,character.only=T)

path_script <- Sys.getenv("SCRIPT_LOCATION")

input <- jsonlite::fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)
print(outputFolder)

source(file.path(path_script,"data/getRangeMapFunc.R"), echo=TRUE)

# Inputs -----------------------------------------------------------------------
# Define species
output<- tryCatch({
sp <- str_to_sentence(input$species)

# Define source of expert range maps
expert_source <- input$expert_source

#-------------------------------------------------------------------------------
# Get range map
#-------------------------------------------------------------------------------

v_path_to_range_map <- c()

for( i in 1:length(sp)){
  source_range_maps <- data.frame(expert_source=expert_source ,
                                  species_name = sp[i]) |>
    dplyr::mutate(function_name=case_when(
      expert_source=="IUCN"~ "get_iucn_range_map",
      expert_source=="MOL"~ "get_mol_range_map",
      expert_source=="QC" ~ "get_qc_range_map"
    ),
    species_path= case_when(
      expert_source=="IUCN"~ sp[i],
      expert_source=="MOL"~ paste0(sp[i],"_mol"),
      expert_source=="QC" ~ paste0(sp[i],"_qc")
    ))

  with(source_range_maps, do.call(function_name,args = list(species_name=species_name)))

  file <- paste0(source_range_maps$species_path,'_range.gpkg')

  if(file.exists(file)){
    sf_range_map <- st_read(file)
  }else{
    path_to_range_map <- NULL
    stop("========== No range map available for ", sp[i] ," at the ", expert_source , " expert source database ==========")
  }

  if (!dir.exists(file.path(outputFolder,sp[i]))){
    dir.create(file.path(outputFolder,sp[i]))
  }else{
    print("dir exists")
  }

  v_path_to_range_map[i] <- file.path(outputFolder, sp[i], file)
  sf::st_write(sf_range_map, v_path_to_range_map[i], append = FALSE  )

  print("========== Expert range map successfully downloaded ==========")
}


# Outputing result to JSON -----------------------------------------------------
output <- list("sf_range_map" = v_path_to_range_map )
}, error = function(e) { list(error = conditionMessage(e)) })
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder, "output.json"))