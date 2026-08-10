#!/usr/bin/env Rscript

## SInAS Step 3: merge standardised alien-species databases.
## Adapted for BON in a Box from MergeDatabases.r (SInAS v2.0).

input <- biab_inputs()

country <- input$country_name$country
country_name <- country$englishName
country_iso3 <- country$ISO3

if (is.null(country_name) || is.null(country_iso3)) {
  stop("country_name must provide both englishName and ISO3.")
}

read_standardised <- function(path, dataset_name) {
  if (is.null(path) || !file.exists(path)) {
    stop(dataset_name, " input does not exist: ", path)
  }
  dat <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  if (ncol(dat) == 1) {
    dat <- read.table(
      path, header = TRUE, stringsAsFactors = FALSE, check.names = FALSE
    )
  }
  required <- c("location", "locationID")
  if (!all(required %in% names(dat))) {
    stop(
      dataset_name, " is missing required columns: ",
      paste(setdiff(required, names(dat)), collapse = ", ")
    )
  }

  country_code_column <- intersect(c("ISO3", "Country_ISO"), names(dat))
  outside_country <- rep(FALSE, nrow(dat))
  if (length(country_code_column) > 0) {
    supplied_code <- normalise_missing(dat[[country_code_column[1]]])
    outside_country <- !is.na(supplied_code) & supplied_code != country_iso3
  } else {
    outside_country <- !is.na(dat$location) & dat$location != "" &
      dat$location != country_name
  }
  if (any(outside_country)) {
    stop(dataset_name, " contains records outside ", country_name, ".")
  }

  ## Match the source workflow: unresolved locations do not enter the merge.
  dat <- dat[!is.na(dat$locationID) & dat$locationID != "", , drop = FALSE]
  dat$origDB <- rep(dataset_name, nrow(dat))
  dat
}

read_report <- function(path, report_name) {
  if (is.null(path) || !file.exists(path)) {
    stop(report_name, " input does not exist: ", path)
  }
  read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

normalise_missing <- function(x) {
  x <- as.character(x)
  x[is.na(x) | trimws(x) %in% c("", "NA")] <- NA_character_
  x
}

combine_values <- function(x) {
  x <- normalise_missing(x)
  values <- unlist(strsplit(x[!is.na(x)], ";\\s*"))
  values <- trimws(values)
  values <- sort(unique(values[nzchar(values)]))
  if (length(values) == 0) return(NA_character_)
  paste(values, collapse = "; ")
}

earliest_event_date <- function(x) {
  x <- normalise_missing(x)
  pieces <- unlist(strsplit(x[!is.na(x)], ";\\s*"))
  years <- suppressWarnings(as.numeric(trimws(pieces)))
  years <- years[!is.na(years)]
  if (length(years) == 0) return(NA_character_)
  as.character(min(years))
}

prepare_dataset <- function(dat) {
  if ("Kingdom_user" %in% names(dat) && !"kingdom" %in% names(dat)) {
    names(dat)[names(dat) == "Kingdom_user"] <- "kingdom"
  }
  excluded <- c(
    "taxon_orig", "location_orig", "Country_ISO",
    "ISO3", "eventDate_orig", "eventDate2_orig", "Taxon_group",
    "stateProvince", "taxonQCnote", "locationQCnote", "matchStatus",
    "matchMethod", "matchNote", "exclusion_reason"
  )
  dat <- dat[, setdiff(names(dat), excluded), drop = FALSE]

  if (!"kingdom" %in% names(dat)) {
    dat$kingdom <- rep(NA_character_, nrow(dat))
  }

  establishment_cols <- grep(
    "^establishmentMeans", names(dat), value = TRUE
  )
  if (length(establishment_cols) == 0) {
    dat$establishmentMeans <- rep("introduced", nrow(dat))
  } else {
    for (column in establishment_cols) {
      empty <- is.na(dat[[column]]) | trimws(as.character(dat[[column]])) == ""
      dat[[column]][empty] <- "introduced"
    }
    if (!"establishmentMeans" %in% names(dat)) {
      names(dat)[names(dat) == establishment_cols[1]] <- "establishmentMeans"
    }
  }
  dat
}

griis <- prepare_dataset(
  read_standardised(input$griis_clean, "GRIIS")
)
first_records <- prepare_dataset(
  read_standardised(input$first_records_clean, "FirstRecords")
)
cleaning_report <- read_report(input$cleaning_summary, "Preparation summary")
qc_report <- read_report(input$qc_status, "Quality-control status")
unmatched_report <- read_report(input$unmatched_values, "Unmatched values")
full_taxa_list <- read_report(input$full_taxa_list, "Full taxonomic list")

required_identity_columns <- c(
  "location", "locationID", "taxon", "scientificName", "taxonID"
)
for (dataset in list(GRIIS = griis, FirstRecords = first_records)) {
  missing_identity <- setdiff(required_identity_columns, names(dataset))
  if (length(missing_identity) > 0) {
    stop(
      "A standardised merge input is missing required identity columns: ",
      paste(missing_identity, collapse = ", ")
    )
  }
}

all_columns <- union(names(griis), names(first_records))
add_missing_columns <- function(dat, columns) {
  for (column in setdiff(columns, names(dat))) {
    dat[[column]] <- rep(NA_character_, nrow(dat))
  }
  dat[, columns, drop = FALSE]
}

combined <- rbind(
  add_missing_columns(griis, all_columns),
  add_missing_columns(first_records, all_columns)
)

## Reproduce the source workflow's introduced/uncertain rule before including
## establishmentMeans in the grouping identity.
core_keys <- c("taxon", "location", "locationID", "taxonID", "scientificName")
core_keys <- core_keys[core_keys %in% names(combined)]
if (!all(c("location", "locationID") %in% core_keys)) {
  stop("Cannot merge without location and locationID.")
}
if (!any(c("taxon", "taxonID", "scientificName") %in% core_keys)) {
  stop("Cannot merge without a taxon, taxonID, or scientificName column.")
}

make_groups <- function(dat, keys) {
  parts <- lapply(dat[keys], function(x) {
    x <- normalise_missing(x)
    ifelse(is.na(x), "<SInAS_NA>", x)
  })
  id <- do.call(interaction, c(parts, list(drop = TRUE, lex.order = TRUE)))
  split(seq_len(nrow(dat)), id)
}

if ("establishmentMeans" %in% names(combined)) {
  core_groups <- make_groups(combined, core_keys)
  for (index in core_groups) {
    values <- normalise_missing(combined$establishmentMeans[index])
    values <- trimws(unlist(strsplit(values[!is.na(values)], ";\\s*")))
    if (all(c("introduced", "uncertain") %in% values)) {
      combined$establishmentMeans[index] <- "introduced; uncertain"
    }
  }
}

first_value <- function(x) {
  x <- normalise_missing(x)
  x <- x[!is.na(x)]
  if (length(x) == 0) return(NA_character_)
  x[[1]]
}

aggregate_data <- function(dat, keys, first_columns = character()) {
  groups <- make_groups(dat, keys)
  rows <- lapply(groups, function(index) {
    out <- dat[index[1], , drop = FALSE]
    for (column in names(dat)) {
      if (column == "eventDate") {
        out[[column]] <- earliest_event_date(dat[[column]][index])
      } else if (column %in% first_columns) {
        out[[column]] <- first_value(dat[[column]][index])
      } else {
        out[[column]] <- combine_values(dat[[column]][index])
      }
    }
    out
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

## First merge records with the complete SInAS taxonomic identity.
primary_keys <- c(core_keys, "establishmentMeans")
primary_keys <- primary_keys[primary_keys %in% names(combined)]
merged_primary <- aggregate_data(combined, primary_keys)

## Report fields that disagree before the source workflow's final
## taxon-location-establishment consolidation.
final_keys <- c("taxon", "location", "establishmentMeans")
final_keys <- final_keys[final_keys %in% names(merged_primary)]
final_groups <- make_groups(merged_primary, final_keys)
conflict_rows <- lapply(final_groups, function(index) {
  if (length(index) < 2) return(NULL)
  checked <- setdiff(
    names(merged_primary),
    c(final_keys, "linkID", "origDB", "bibliographicCitation", "eventDate")
  )
  rows <- lapply(checked, function(column) {
    raw_values <- normalise_missing(merged_primary[[column]][index])
    raw_values <- sort(unique(raw_values[!is.na(raw_values)]))
    if (length(raw_values) < 2) return(NULL)
    data.frame(
      taxon = first_value(merged_primary$taxon[index]),
      location = first_value(merged_primary$location[index]),
      establishmentMeans = first_value(
        merged_primary$establishmentMeans[index]
      ),
      column = column,
      values = paste(raw_values, collapse = " | "),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
})
merge_conflicts <- do.call(rbind, conflict_rows)
if (is.null(merge_conflicts)) {
  merge_conflicts <- data.frame(
    taxon = character(), location = character(),
    establishmentMeans = character(), column = character(),
    values = character(), stringsAsFactors = FALSE
  )
}

## Match the source workflow's final identity while retaining the first
## reviewed taxonomic identifiers and combining provenance fields.
identity_columns <- intersect(
  c("locationID", "taxonID", "scientificName", "kingdom"),
  names(merged_primary)
)
merged <- aggregate_data(merged_primary, final_keys, identity_columns)

## Use the most informative habitat available for each resolved taxon.
if (all(c("taxonID", "habitat") %in% names(merged))) {
  taxon_groups <- split(
    seq_len(nrow(merged)),
    ifelse(is.na(merged$taxonID), "<SInAS_NA>", merged$taxonID)
  )
  for (index in taxon_groups) {
    habitats <- normalise_missing(merged$habitat[index])
    available <- habitats[!is.na(habitats)]
    if (length(available) > 0) {
      merged$habitat[index] <- available[which.max(nchar(available))]
    }
  }
}

if ("bibliographicCitation" %in% names(merged)) {
  merged$bibliographicCitation <- gsub("[\"']", "", merged$bibliographicCitation)
}

# Reattach the reviewed GBIF hierarchy exactly as the original P3 merge does.
taxonomy_columns <- c(
  "taxonID", "kingdom", "phylum", "class", "order", "family"
)
missing_taxonomy_columns <- setdiff(taxonomy_columns, names(full_taxa_list))
if (length(missing_taxonomy_columns) > 0) {
  stop(
    "Full taxonomic list is missing required columns: ",
    paste(missing_taxonomy_columns, collapse = ", ")
  )
}
taxonomy <- unique(full_taxa_list[, taxonomy_columns, drop = FALSE])
taxonomy$taxonID <- as.character(taxonomy$taxonID)
taxonomy <- taxonomy[
  !is.na(normalise_missing(taxonomy$taxonID)), , drop = FALSE
]
if (nrow(taxonomy) == 0) {
  stop("Full taxonomic list contains no usable taxonID values.")
}
taxonomy_groups <- split(seq_len(nrow(taxonomy)), taxonomy$taxonID)
hierarchy_columns <- setdiff(taxonomy_columns, "taxonID")
conflicting_taxon_ids <- names(taxonomy_groups)[vapply(
  taxonomy_groups,
  function(index) {
    any(vapply(
      hierarchy_columns,
      function(column) {
        values <- normalise_missing(taxonomy[[column]][index])
        length(unique(values[!is.na(values)])) > 1
      },
      logical(1)
    ))
  },
  logical(1)
)]
if (length(conflicting_taxon_ids) > 0) {
  stop(
    "Full taxonomic list contains conflicting hierarchies for taxonID: ",
    paste(conflicting_taxon_ids, collapse = ", ")
  )
}
taxonomy <- do.call(rbind, lapply(taxonomy_groups, function(index) {
  out <- taxonomy[index[[1]], , drop = FALSE]
  for (column in hierarchy_columns) {
    out[[column]] <- first_value(taxonomy[[column]][index])
  }
  out
}))
rownames(taxonomy) <- NULL
merged$taxonID <- as.character(merged$taxonID)
taxonomy_index <- match(merged$taxonID, taxonomy$taxonID)
missing_taxonomy <- is.na(taxonomy_index) & !is.na(normalise_missing(merged$taxonID))
if (any(missing_taxonomy)) {
  stop(
    "No reviewed taxonomy found for merged taxonID: ",
    paste(unique(merged$taxonID[missing_taxonomy]), collapse = ", ")
  )
}
for (column in setdiff(taxonomy_columns, "taxonID")) {
  merged[[column]] <- taxonomy[[column]][taxonomy_index]
}

# Match the original taxonomic ordering.
sort_columns <- intersect(
  c(
    "location", "kingdom", "phylum", "class", "order", "family",
    "scientificName"
  ),
  names(merged)
)
if (length(sort_columns) > 0 && nrow(merged) > 0) {
  ordering <- do.call(order, c(merged[sort_columns], list(na.last = TRUE)))
  merged <- merged[ordering, , drop = FALSE]
}

# Keep a stable, deliberate output schema. The first group follows the
# original P3 output; taxonomy and BON in a Box provenance are retained
# explicitly rather than allowing arbitrary upstream columns to leak through.
output_columns <- c(
  "location", "locationID", "taxon", "scientificName", "taxonID",
  "eventDate", "habitat", "occurrenceStatus", "establishmentMeans",
  "degreeOfEstablishment", "pathway", "origDB", "bibliographicCitation",
  "kingdom", "phylum", "class", "order", "family",
  "linkID", "isInvasive", "isInvasiveInCountry", "isInvasiveAnywhere",
  "taxaGroup", "sourceLocation", "sourceLocationID", "sourceVersion",
  "sourceDOI", "sourceFile"
)
merged <- merged[, intersect(output_columns, names(merged)), drop = FALSE]

summary <- data.frame(
  country = country_name,
  ISO3 = country_iso3,
  source = c("GRIIS", "FirstRecords", "Merged"),
  records = c(nrow(griis), nrow(first_records), nrow(merged)),
  merge_conflicts = c(NA_integer_, NA_integer_, nrow(merge_conflicts)),
  stringsAsFactors = FALSE
)

report_column <- function(dat, column, default = "") {
  if (column %in% names(dat)) return(dat[[column]])
  rep(default, nrow(dat))
}

## Keep review information out of the merged table while making it available
## in one human-readable final data-quality product.
quality_control_rows <- data.frame(
  report_type = rep("quality_control", nrow(qc_report)),
  status = as.character(report_column(qc_report, "status")),
  dataset = rep("", nrow(qc_report)),
  check = as.character(report_column(qc_report, "check")),
  field = rep("", nrow(qc_report)),
  original_value = rep("", nrow(qc_report)),
  standardised_value = rep("", nrow(qc_report)),
  affected_records = suppressWarnings(as.numeric(
    report_column(qc_report, "affected_records", NA)
  )),
  details = rep("", nrow(qc_report)),
  action = as.character(report_column(qc_report, "action")),
  included_in_merge = rep("", nrow(qc_report)),
  taxon = rep("", nrow(qc_report)),
  location = rep("", nrow(qc_report)),
  establishmentMeans = rep("", nrow(qc_report)),
  conflicting_values = rep("", nrow(qc_report)),
  stringsAsFactors = FALSE
)

unmatched_rows <- data.frame(
  report_type = rep("unmatched_value", nrow(unmatched_report)),
  status = rep("WARNING", nrow(unmatched_report)),
  dataset = as.character(report_column(unmatched_report, "dataset")),
  check = as.character(report_column(unmatched_report, "check")),
  field = as.character(report_column(unmatched_report, "field")),
  original_value = as.character(report_column(
    unmatched_report, "original_value"
  )),
  standardised_value = as.character(report_column(
    unmatched_report, "standardised_value"
  )),
  affected_records = suppressWarnings(as.numeric(
    report_column(unmatched_report, "affected_records", NA)
  )),
  details = as.character(report_column(unmatched_report, "details")),
  action = as.character(report_column(unmatched_report, "action")),
  included_in_merge = as.character(report_column(
    unmatched_report, "included_in_merge"
  )),
  taxon = rep("", nrow(unmatched_report)),
  location = rep("", nrow(unmatched_report)),
  establishmentMeans = rep("", nrow(unmatched_report)),
  conflicting_values = rep("", nrow(unmatched_report)),
  stringsAsFactors = FALSE
)

conflict_rows_report <- data.frame(
  report_type = rep("merge_conflict", nrow(merge_conflicts)),
  status = rep("WARNING", nrow(merge_conflicts)),
  dataset = rep("Merged", nrow(merge_conflicts)),
  check = rep("merge", nrow(merge_conflicts)),
  field = as.character(report_column(merge_conflicts, "column")),
  original_value = rep("", nrow(merge_conflicts)),
  standardised_value = rep("", nrow(merge_conflicts)),
  affected_records = rep(NA_real_, nrow(merge_conflicts)),
  details = rep(
    "Multiple values were combined during final record consolidation",
    nrow(merge_conflicts)
  ),
  action = rep("Values retained in the merged record", nrow(merge_conflicts)),
  included_in_merge = rep("yes", nrow(merge_conflicts)),
  taxon = as.character(report_column(merge_conflicts, "taxon")),
  location = as.character(report_column(merge_conflicts, "location")),
  establishmentMeans = as.character(report_column(
    merge_conflicts, "establishmentMeans"
  )),
  conflicting_values = as.character(report_column(merge_conflicts, "values")),
  stringsAsFactors = FALSE
)

data_quality_report <- rbind(
  quality_control_rows, unmatched_rows, conflict_rows_report
)

required_summary_columns <- c(
  "dataset", "input_records", "clean_records", "unresolved_terms",
  "unresolved_locations", "unresolved_taxa", "excluded_from_merge"
)
if (!all(required_summary_columns %in% names(cleaning_report))) {
  stop(
    "Preparation summary is missing required columns: ",
    paste(setdiff(required_summary_columns, names(cleaning_report)), collapse = ", ")
  )
}

overall_qc <- as.character(report_column(qc_report, "status", "UNKNOWN")[
  match("overall", report_column(qc_report, "check"))
])
if (length(overall_qc) == 0 || is.na(overall_qc)) overall_qc <- "UNKNOWN"

preparation_rows <- data.frame(
  country = rep(country_name, nrow(cleaning_report)),
  ISO3 = rep(country_iso3, nrow(cleaning_report)),
  stage = rep("preparation", nrow(cleaning_report)),
  dataset = as.character(cleaning_report$dataset),
  input_records = suppressWarnings(as.numeric(cleaning_report$input_records)),
  output_records = suppressWarnings(as.numeric(cleaning_report$clean_records)),
  unresolved_terms = suppressWarnings(as.numeric(
    cleaning_report$unresolved_terms
  )),
  unresolved_locations = suppressWarnings(as.numeric(
    cleaning_report$unresolved_locations
  )),
  unresolved_taxa = suppressWarnings(as.numeric(
    cleaning_report$unresolved_taxa
  )),
  excluded_from_merge = suppressWarnings(as.numeric(
    cleaning_report$excluded_from_merge
  )),
  merge_conflicts = rep(NA_real_, nrow(cleaning_report)),
  QC_status = rep(overall_qc, nrow(cleaning_report)),
  stringsAsFactors = FALSE
)

merge_row <- data.frame(
  country = country_name,
  ISO3 = country_iso3,
  stage = "merge",
  dataset = "Merged",
  input_records = nrow(griis) + nrow(first_records),
  output_records = nrow(merged),
  unresolved_terms = sum(preparation_rows$unresolved_terms, na.rm = TRUE),
  unresolved_locations = sum(
    preparation_rows$unresolved_locations, na.rm = TRUE
  ),
  unresolved_taxa = sum(preparation_rows$unresolved_taxa, na.rm = TRUE),
  excluded_from_merge = sum(
    preparation_rows$excluded_from_merge, na.rm = TRUE
  ),
  merge_conflicts = nrow(merge_conflicts),
  QC_status = overall_qc,
  stringsAsFactors = FALSE
)
run_summary <- rbind(preparation_rows, merge_row)

merged_path <- file.path(outputFolder, paste0(country_iso3, "_SInAS_merged.csv"))
summary_path <- file.path(outputFolder, paste0(country_iso3, "_SInAS_merge_summary.csv"))
conflicts_path <- file.path(
  outputFolder, paste0(country_iso3, "_SInAS_merge_conflicts.csv")
)
data_quality_path <- file.path(
  outputFolder, paste0(country_iso3, "_SInAS_data_quality_report.csv")
)
run_summary_path <- file.path(
  outputFolder, paste0(country_iso3, "_SInAS_run_summary.csv")
)

write.csv(merged, merged_path, row.names = FALSE, na = "")
write.csv(summary, summary_path, row.names = FALSE, na = "")
write.csv(merge_conflicts, conflicts_path, row.names = FALSE, na = "")
write.csv(data_quality_report, data_quality_path, row.names = FALSE, na = "")
write.csv(run_summary, run_summary_path, row.names = FALSE, na = "")

biab_output("merged_dataset", merged_path)
biab_output("data_quality_report", data_quality_path)
biab_output("run_summary", run_summary_path)
biab_output("merge_summary", summary_path)
biab_output("merge_conflicts", conflicts_path)
