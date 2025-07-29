library(magrittr)

input <- biab_inputs()

splist <- read.csv(input$splist)

token <- Sys.getenv("IUCN_TOKEN")
if (token == "") {
  biab_error_stop("Please specify an IUCN token in your environment file")
}
print(token)

# Find the species in the Red List that are improving in threat category
sp_improving <- rredlist::rl_pop_trends(key = token, code = "0", latest = TRUE, scope_code = 1)$assessments
sp_improving <- sp_improving %>% dplyr::distinct(sis_taxon_id, .keep_all = TRUE)
print(sprintf("Number of species improving in total: %s", nrow(sp_improving)))

#Filter the species list from the country of interest with the list of improving species
sp_improving_country <- splist %>% dplyr::filter(sis_taxon_id %in% sp_improving$sis_taxon_id)
total_sp <- nrow(splist)
num_improving <- nrow(sp_improving_country)
print(sprintf("Number of species improving in country of interest: %s", num_improving))
print(sprintf("Total species in country of interest on the Red List: %s", total_sp))

if (num_improving == 0) {
    percentage <- 0.00
} else {
    percentage <- round((num_improving / total_sp) * 100, 2)
}

biab_output("percent_improving", percentage)
