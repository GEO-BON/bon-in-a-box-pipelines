## Load libraries ###
packagesList <- list("magrittr") # Explicitly list packages needed that must be fully loaded in the environment. Functions from other libraries will be accessible via '::'.
lapply(packagesList, library, character.only = TRUE) # Load explicitly listed libraries

input <- biab_inputs()

# Script body ####
token <- Sys.getenv("IUCN_TOKEN")
if (token == "") {
  biab_error_stop("Please specify an IUCN token in your environment file")
}
print(token)

## Load sp country ####

UICN_countries <- rredlist::rl_countries(key = token)
UICN_isocode <- UICN_countries$countries$code[UICN_countries$countries$description$en == input$country]

print(sprintf("Loading species for %s...", input$country))
UICN_country <- rredlist::rl_countries(code = UICN_isocode, key = token)$assessments

## Load sp taxonomic group ####
print(sprintf("Loading species for '%s' taxon group...", input$taxonomic_group))
UICN_taxon <- rredlist::rl_comp_groups(name = input$taxonomic_group, key = token)$assessments

## Filter country list by taxonomic group ####
iucn_splist <- UICN_taxon %>% dplyr::filter(sis_taxon_id %in% UICN_country$sis_taxon_id)

# Write results ####
iucn_splist <- iucn_splist %>%
    dplyr::rename(scientific_name = taxon_scientific_name)
iucn_splist$scopes <- sapply(iucn_splist$scopes, function(x) paste(unlist(x), collapse = ", "))
iucn_splist_path <- file.path(outputFolder, paste0("iucn_splist", ".csv")) # Define the file path
write.csv(iucn_splist, iucn_splist_path, row.names = F) # write result

biab_output("iucn_splist", iucn_splist_path)