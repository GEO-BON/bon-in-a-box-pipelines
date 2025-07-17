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

country <- input$country

biab_output("country", country)

## Load sp country ####

IUCN_countries <- rredlist::rl_countries(key = token)
IUCN_isocode <- IUCN_countries$countries$code[IUCN_countries$countries$description$en == input$country]

print(sprintf("Loading species for %s...", input$country))
IUCN_country <- rredlist::rl_countries(code = IUCN_isocode, key = token)$assessments

if (nrow(IUCN_country) == 0) {
  biab_error_stop("Could not find any species in the country of interest")
}

IUCN_country$scopes <- sapply(IUCN_country$scopes, function(x) paste(unlist(x), collapse = ", "))
IUCN_country_path <- file.path(outputFolder, paste0("IUCN_country_splist", ".csv")) # Define the file path
write.csv(IUCN_country, IUCN_country_path, row.names = F) # write result

biab_output("iucn_country_splist", IUCN_country_path)

citation <- rredlist::rl_citation(key = token)

# Extract citation
citation <- capture.output(print(citation))
lines <- trimws(unlist(strsplit(citation, "\n")))
start <- grep("^IUCN \\([0-9]{4}\\)", lines)
end <- grep("Accessed on", lines)
end <- end[end >= start][1]

citation <- paste(lines[start:end], collapse = " ")

biab_output("api_citation", citation)