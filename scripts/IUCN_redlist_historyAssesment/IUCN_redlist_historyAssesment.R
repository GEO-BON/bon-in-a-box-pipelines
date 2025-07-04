# Load libraries
packagesList <- list("magrittr", "rredlist", "ggplot2") # Explicitly list the required packages throughout the entire routine. Explicitly listing the required packages throughout the routine ensures that only the necessary packages are listed. Unlike 'packagesNeed', this list includes packages with functions that cannot be directly called using the '::' syntax. By using '::', specific functions or objects from a package can be accessed directly without loading the entire package. Loading an entire package involves loading all the functions and objects
lapply(packagesList, library, character.only = TRUE) # Load libraries - packages

input <- biab_inputs()

#### Species list by country ####
# Load IUCN token----
token <- Sys.getenv("IUCN_TOKEN")
if (token == "") {
  biab_error_stop("Please specify an IUCN token in your environment file")
}
print(sprintf("Token: %s", token))

iucn_splist <- data.table::fread(input$species_data) %>% as.data.frame()

print("Loading historical assessment data...")
pbapply::pboptions(type = "timer")
iucn_history_assessment_data <- pbapply::pblapply(iucn_splist[, input$sp_col], function(x) {
  parts <- strsplit(x, " ")[[1]]
  gn <- parts[1]
  sp <- parts[2]
  subvar <- NULL

  if (length(parts) >= 4 && parts[3] %in% c("ssp.", "subsp.", "var.")) {
    subvar <- parts[4]
  }
  Sys.sleep(0.01)

  tryCatch(
    {
      rredlist::rl_species(genus = gn, species = sp, infra = subvar, key = token)$assessments
    },
    error = function(e) {
      NULL
    }
  )
})
print("Done!")
iucn_history_assessment_data <- dplyr::bind_rows(iucn_history_assessment_data)
iucn_history_assessment_data <- iucn_history_assessment_data[, c("taxon_scientific_name", "year_published", "red_list_category_code")]

iucn_history_assessment_data <- iucn_history_assessment_data %>%
  dplyr::rename(scientific_name = taxon_scientific_name, code = red_list_category_code, assess_year = year_published)

## Write results ####
iucn_history_assessment_data_path <- file.path(outputFolder, paste0("iucn_history_assessment_data", ".csv")) # Define the file path
write.csv(iucn_history_assessment_data, iucn_history_assessment_data_path, row.names = F) # write result

citation <- rredlist::rl_citation(key = token)

# Extract citation
citation <- capture.output(print(citation))
lines <- trimws(unlist(strsplit(citation, "\n")))
start <- grep("^IUCN \\([0-9]{4}\\)", lines)
end <- grep("Accessed on", lines)
end <- end[end >= start][1]

citation <- paste(lines[start:end], collapse = " ")

biab_output("api_citation", citation)
biab_output("iucn_history_assessment_data", iucn_history_assessment_data_path)
