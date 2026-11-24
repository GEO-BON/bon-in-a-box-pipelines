# Map an optional national checklist to SInAS input columns.
# Taxonomy and event-date standardisation are handled by SInAS preparation.

input <- biab_inputs()

national_checklist <- input$national_checklist
country_name <- input$country_name$country$englishName
iso3 <- input$country_name$country$ISO3
species_column <- input$species_column
first_record_column <- input$first_record_column
dataset_citation <- input$dataset_citation

if (is.null(national_checklist)) {
  biab_info("No national checklist provided. Skipping import.")
  biab_output("national_checklist", NULL)
} else {
  if (length(national_checklist) != 1L || !is.character(national_checklist)) {
    biab_error_stop("Provide a single national checklist file path.")
  }
  # Read as text to preserve original names and date representations.
  uploaded <- read.csv(
    national_checklist, check.names = FALSE,
    stringsAsFactors = FALSE, colClasses = "character", na.strings = character()
  )
  if (nrow(uploaded) == 0L) {
    biab_error_stop("The uploaded checklist contains no species records.")
  }

  if (length(species_column) != 1L || !is.character(species_column) ||
      is.na(species_column) || !nzchar(trimws(species_column))) {
    biab_error_stop("Enter the name of the species column.")
  }
  if (!species_column %in% names(uploaded)) {
    biab_error_stop("The specified species column does not exist in the national checklist.")
  }
  taxon_orig <- uploaded[[species_column]]
  taxon <- trimws(taxon_orig)
  blank_rows <- which(is.na(taxon) | !nzchar(taxon))
  if (length(blank_rows) > 0L) {
    biab_error_stop(paste0(
      "Species names are blank in data row(s): ",
      paste(blank_rows, collapse = ", "), ". Row numbers exclude the header."
    ))
  }

  eventDate_orig <- rep(NA_character_, nrow(uploaded))
  if (length(first_record_column) == 0L ||
      (length(first_record_column) == 1L &&
       (is.na(first_record_column) || !nzchar(trimws(first_record_column))))) {
    biab_info("No first-record column provided. Dates will remain missing for downstream preparation.")
  } else {
    if (length(first_record_column) != 1L || !is.character(first_record_column)) {
      biab_error_stop("Enter a single first-record column name, or leave it blank.")
    }
    if (!first_record_column %in% names(uploaded)) {
      biab_error_stop("The specified first-record column does not exist in the national checklist.")
    }
    eventDate_orig <- uploaded[[first_record_column]]
  }
  eventDate <- trimws(eventDate_orig)
  eventDate[is.na(eventDate) | !nzchar(eventDate)] <- NA_character_

  if (length(dataset_citation) == 0L ||
      (length(dataset_citation) == 1L &&
       (is.na(dataset_citation) || !nzchar(trimws(dataset_citation))))) {
    dataset_citation <- "user_input_data"
    biab_info("No dataset citation provided. Using user_input_data.")
  } else if (length(dataset_citation) != 1L || !is.character(dataset_citation)) {
    biab_error_stop("Enter a single dataset citation, or leave it blank.")
  }

  national_checklist <- data.frame(
    sourceRow = seq_len(nrow(uploaded)),
    taxon = taxon,
    eventDate = eventDate,
    bibliographicCitation = dataset_citation,
    location = country_name,
    ISO3 = iso3,
    taxon_orig = taxon_orig,
    eventDate_orig = eventDate_orig,
    stringsAsFactors = FALSE
  )

  output_path <- file.path(outputFolder, "national_checklist.csv")
  write.csv(national_checklist, output_path, row.names = FALSE, na = "")
  biab_output("national_checklist", output_path)
}
