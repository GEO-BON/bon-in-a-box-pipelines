## Load libraries ###
packagesList <- list("magrittr") # Explicitly list packages needed that must be fully loaded in the environment. Functions from other libraries will be accessible via '::'.
lapply(packagesList, library, character.only = TRUE) # Load explicitly listed libraries

input <- biab_inputs()

IUCN_country <- read.csv(input$splist_country)
iucn_splist <- IUCN_country

taxonomic_group <- input$taxonomic_group
use <- input$species_use
threat <- input$threat

if (taxonomic_group[1] != "all") {
  print("Filtered by taxonomic group.")
  IUCN_taxon <- read.csv(input$splist_taxon)
  ## Filter country list by taxonomic group ####
  iucn_splist <- IUCN_taxon %>% dplyr::filter(sis_taxon_id %in% IUCN_country$sis_taxon_id)
}

if (use[1] != "Don't filter by species use") {
  print("Filtered by species use.")
  IUCN_use <- read.csv(input$splist_use)
  ## Filter country list by use and trade list ####
  iucn_splist <- IUCN_use %>% dplyr::filter(sis_taxon_id %in% IUCN_country$sis_taxon_id)
}

if (threat[1] != "Do not filter by threat category") {
  print("Filtered by threat category.")
  IUCN_threat <- read.csv(input$splist_threat)
  ## Filter country list by threat list ####
  iucn_splist <- IUCN_threat %>% dplyr::filter(sis_taxon_id %in% IUCN_country$sis_taxon_id)
}

if (nrow(iucn_splist) == 0) {
  biab_error_stop("Could not find any species in the country of interest based on the applied filters")
}

# Write results ####
iucn_splist <- iucn_splist %>%
  dplyr::rename(scientific_name = taxon_scientific_name)

iucn_splist_path <- file.path(outputFolder, paste0("iucn_splist", ".csv")) # Define the file path
write.csv(iucn_splist, iucn_splist_path, row.names = F) # write result

biab_output("iucn_splist", iucn_splist_path)