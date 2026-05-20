library(dplyr)
library(readxl)
library(tidyr)
library(stringr)
library(rredlist)

## Load inputs ##
input <- biab_inputs()

species <- input$species
conversion_table <- input$conversion_table

token <- Sys.getenv("IUCN_TOKEN")
if (token == "") {
  biab_error_stop("Please specify an IUCN token in your environment file")
}

# Format conversion table
conversion_table <- read.csv(conversion_table)
conversion_table_tidy <- conversion_table |> dplyr::count(HABITAT_IUCN, ESA_cod, ESA_cov) |> 
  separate_rows(HABITAT_IUCN, sep="; ") |> 
  mutate(IUCN_code = gsub("\\.$" , "" , str_extract( HABITAT_IUCN, "\\d*\\.*\\d*")) , .before = HABITAT_IUCN) |> 
  mutate(IUCN_code = gsub("\\.", "_", IUCN_code)) |>
  select(-n)

# Get habitat codes for each species
habitat_codes <- list()
for (i in 1:length(species)) {
  print(paste("Processing species", species[i]))
# splitting species name into genus and species for API call
species_genus <- str_split(species[i], " ")[[1]][1]
species_species <- str_split(species[i], " ")[[1]][2]
# Get habitat codes for the species using the IUCN API
species_habitats <- rredlist::rl_species_latest(genus = species_genus, species = species_species, key = token)$habitats

# Use conversion table to get ESA habitat codes for each species
habitat_codes_sp <- conversion_table_tidy |> 
  mutate(species = species[i]) |>
  filter(IUCN_code %in% species_habitats$code) |> 
  select(species, ESA_cod, ESA_cov)

habitat_codes[[i]] <- habitat_codes_sp
}

# habitat codes for all species
habitat_codes_df <- bind_rows(habitat_codes)

# Save table as csv
habitat_codes_path <- file.path(outputFolder, "habitat_codes.csv)")
write.csv(habitat_codes_df, habitat_codes_path, row.names = FALSE)

# habitat codes in conversion table not found in species_habitats
missing_codes <- species_habitats |>
  distinct(code) |>
  filter(!code %in% conversion_table_tidy$IUCN_code)

nrow(missing_codes)

# output results
biab_output("habitats", habitat_codes_path)