library(dplyr)
library(gt)
library(readr)
library(rjson)

input <- biab_inputs()

merged_data <- read.csv(input$merged_dataset, stringsAsFactors = FALSE)
gbif_observations <- read.csv(input$gbif_country_observations, stringsAsFactors = FALSE)

required_merged_columns <- c(
  "taxon", "kingdom", "origDB", "isInvasiveInCountry", "eventDate"
)
missing_merged_columns <- setdiff(required_merged_columns, colnames(merged_data))
if (length(missing_merged_columns) > 0) {
  biab_error_stop(paste(
    "Merged dataset is missing required column(s):",
    paste(missing_merged_columns, collapse = ", ")
  ))
}

if (!"year" %in% colnames(gbif_observations)) {
  biab_error_stop("GBIF observations file is missing required column: year")
}

gbif_count_column <- dplyr::case_when(
  "RecordsCount" %in% colnames(gbif_observations) ~ "RecordsCount",
  "count" %in% colnames(gbif_observations) ~ "count",
  TRUE ~ NA_character_
)
if (is.na(gbif_count_column)) {
  biab_error_stop("GBIF observations file must contain either RecordsCount or count")
}

safe_percent <- function(numerator, denominator) {
  if (is.na(denominator) || denominator == 0) {
    return(NA_real_)
  }
  round(numerator / denominator * 100, 2)
}

format_count_percent <- function(count, percent) {
  if (is.na(percent)) {
    return(paste0(count, " (NA%)"))
  }
  paste0(count, " (", percent, "%)")
}

format_year_taxa <- function(records) {
  if (nrow(records) == 0) {
    return(NA_character_)
  }
  year <- unique(records$eventDate)
  taxa <- paste(unique(records$taxon), collapse = ", ")
  paste0(paste(year, collapse = ", "), " (", taxa, ")")
}

filter_min_year <- function(records) {
  if (nrow(records) == 0) {
    return(records)
  }
  records %>% filter(eventDate == min(eventDate, na.rm = TRUE))
}

filter_max_year <- function(records) {
  if (nrow(records) == 0) {
    return(records)
  }
  records %>% filter(eventDate == max(eventDate, na.rm = TRUE))
}

country_label <- if ("location" %in% colnames(merged_data)) {
  paste(unique(stats::na.omit(merged_data$location)), collapse = ", ")
} else if ("country" %in% colnames(gbif_observations)) {
  paste(unique(stats::na.omit(gbif_observations$country)), collapse = ", ")
} else {
  "Selected country"
}

merged_data <- merged_data %>%
  mutate(
    kingdom = stringr::str_to_title(kingdom),
    isInvasiveInCountry = as.character(isInvasiveInCountry),
    eventDate = suppressWarnings(as.integer(eventDate))
  )

griis_only <- merged_data %>%
  filter(grepl("GRIIS", origDB, ignore.case = TRUE))

invasive_country <- griis_only %>%
  filter(grepl("TRUE", isInvasiveInCountry, ignore.case = TRUE))

number_of_species <- nrow(griis_only)

count_ias_country <- nrow(invasive_country)
count_ias_country_pcnt <- safe_percent(count_ias_country, number_of_species)

count_ias_country_animals <- invasive_country %>%
  filter(kingdom == "Animalia") %>%
  nrow()
count_ias_country_plants <- invasive_country %>%
  filter(kingdom == "Plantae") %>%
  nrow()

count_ias_country_pcnt_animals <- safe_percent(
  count_ias_country_animals,
  count_ias_country
)
count_ias_country_pcnt_plants <- safe_percent(
  count_ias_country_plants,
  count_ias_country
)

with_first_records <- invasive_country %>%
  filter(!is.na(eventDate))

count_ias_country_with_fr <- nrow(with_first_records)
count_ias_country_with_fr_animals <- with_first_records %>%
  filter(kingdom == "Animalia") %>%
  nrow()
count_ias_country_with_fr_plants <- with_first_records %>%
  filter(kingdom == "Plantae") %>%
  nrow()

count_ias_country_with_fr_pcnt <- safe_percent(
  count_ias_country_with_fr,
  count_ias_country
)
count_ias_country_with_fr_pcnt_animals <- safe_percent(
  count_ias_country_with_fr_animals,
  count_ias_country
)
count_ias_country_with_fr_pcnt_plants <- safe_percent(
  count_ias_country_with_fr_plants,
  count_ias_country
)

count_ias_country_with_fr_post1970 <- with_first_records %>%
  filter(eventDate >= 1970) %>%
  nrow()
count_ias_country_with_fr_pre1970 <- with_first_records %>%
  filter(eventDate < 1970) %>%
  nrow()

count_ias_country_with_fr_pcnt_post1970 <- safe_percent(
  count_ias_country_with_fr_post1970,
  count_ias_country_with_fr
)
count_ias_country_with_fr_pcnt_pre1970 <- safe_percent(
  count_ias_country_with_fr_pre1970,
  count_ias_country_with_fr
)

earliest_record_pre1970 <- with_first_records %>%
  filter(eventDate < 1970) %>%
  filter_min_year()

earliest_record_post1970 <- with_first_records %>%
  filter(eventDate >= 1970) %>%
  filter_min_year()

latest_record <- with_first_records %>%
  filter_max_year()

summary <- tibble::tibble(
  Group = c(
    "Total Count",
    "Total Count",
    "Taxonomic Group",
    "Taxonomic Group",
    "First Records",
    "First Records",
    "First Records",
    "First Records",
    "First Records",
    "Date Range",
    "Date Range",
    "Date Range"
  ),
  Variable = c(
    "Number of IAS",
    "IAS InCountry Proportion",
    "Plantae",
    "Animalia",
    "All Species",
    "Plantae",
    "Animalia",
    "Pre 1970",
    "Post 1970",
    "Earliest Record - Pre 1970",
    "Earliest Record - Post 1970",
    "Most Recent Record"
  ),
  isInvasiveInCountry = c(
    format_count_percent(count_ias_country, count_ias_country_pcnt),
    NA_character_,
    format_count_percent(count_ias_country_plants, count_ias_country_pcnt_plants),
    format_count_percent(count_ias_country_animals, count_ias_country_pcnt_animals),
    format_count_percent(count_ias_country_with_fr, count_ias_country_with_fr_pcnt),
    format_count_percent(count_ias_country_with_fr_plants, count_ias_country_with_fr_pcnt_plants),
    format_count_percent(count_ias_country_with_fr_animals, count_ias_country_with_fr_pcnt_animals),
    format_count_percent(count_ias_country_with_fr_pre1970, count_ias_country_with_fr_pcnt_pre1970),
    format_count_percent(count_ias_country_with_fr_post1970, count_ias_country_with_fr_pcnt_post1970),
    format_year_taxa(earliest_record_pre1970),
    format_year_taxa(earliest_record_post1970),
    format_year_taxa(latest_record)
  )
)

first_records_by_year <- with_first_records %>%
  count(year = eventDate, name = "firstRecordCount")

gbif_by_year <- gbif_observations %>%
  transmute(
    year = as.integer(year),
    gbifRecordsCount = as.numeric(.data[[gbif_count_column]])
  ) %>%
  group_by(year) %>%
  summarise(gbifRecordsCount = sum(gbifRecordsCount, na.rm = TRUE), .groups = "drop")

annual_summary <- full_join(gbif_by_year, first_records_by_year, by = "year") %>%
  arrange(year) %>%
  mutate(
    gbifRecordsCount = tidyr::replace_na(gbifRecordsCount, 0),
    firstRecordCount = tidyr::replace_na(firstRecordCount, 0)
  )

summary_table <- gt(summary,
                    groupname_col = "Group",
                    rowname_col = "Variable") %>%
  tab_header(
    title = md(paste0("**Integrated Data Summary: ", country_label, "**")),
    subtitle = paste0("Total species in checklists: ", number_of_species)
  )

summary_csv_path <- file.path(outputFolder, "ias_summary.csv")
annual_summary_path <- file.path(outputFolder, "ias_annual_summary.csv")
summary_table_path <- file.path(outputFolder, "ias_summary.html")

write.csv(summary, summary_csv_path, row.names = FALSE)
write.csv(annual_summary, annual_summary_path, row.names = FALSE)
gt::gtsave(summary_table, summary_table_path)

biab_output("ias_summary", summary_csv_path)
biab_output("ias_annual_summary", annual_summary_path)
biab_output("ias_summary_table", summary_table_path)

