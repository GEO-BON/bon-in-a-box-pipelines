## Load libraries ###
packagesList <- list("magrittr") # Explicitly list packages needed that must be fully loaded in the environment. Functions from other libraries will be accessible via '::'.
lapply(packagesList, library, character.only = TRUE) # Load explicitly listed libraries

input <- biab_inputs()

UICN_taxon <- read.csv(input$splist_taxon)
UICN_country <- read.csv(input$splist_country)

## Filter country list by taxonomic group ####
iucn_splist <- UICN_taxon %>% dplyr::filter(sis_taxon_id %in% UICN_country$sis_taxon_id)

if (nrow(iucn_splist) == 0) {
  biab_error_stop("Could not find any species of the taxon group in the country of interest")
}

# Write results ####
iucn_splist <- iucn_splist %>%
  dplyr::rename(scientific_name = taxon_scientific_name)
iucn_splist$scopes <- sapply(iucn_splist$scopes, function(x) paste(unlist(x), collapse = ", "))
iucn_splist_path <- file.path(outputFolder, paste0("iucn_splist", ".csv")) # Define the file path
write.csv(iucn_splist, iucn_splist_path, row.names = F) # write result

biab_output("iucn_splist", iucn_splist_path)