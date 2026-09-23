#!/usr/bin/env Rscript

## SInAS Step 3: merge standardised alien-species databases.
## Adapted for BON in a Box from MergeDatabases.r (SInAS v2.0).

input <- biab_inputs()

country <- input$country_name$country
country_name <- country$englishName
country_iso3 <- country$ISO3
# BON country selectors can supply a suffixed code such as AUS_1.
# SInAS uses the standard three-letter code for country/location matching.
country_iso3 <- sub("_[0-9]+$", "", toupper(trimws(as.character(country_iso3))))
if (length(country_iso3) != 1L || is.na(country_iso3) || !grepl("^[A-Z]{3}$", country_iso3)) {
  stop("Select a country with a valid three-letter ISO3 code.")
}

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
    dat$kingdom <- dat$Kingdom_user
  }
  if (!"Kingdom_user" %in% names(dat) && "kingdom" %in% names(dat)) {
    dat$Kingdom_user <- dat$kingdom
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

kingdom_with_source_fallback <- function(reviewed, source) {
  reviewed <- normalise_missing(reviewed)
  source <- vapply(as.character(source), function(value) {
    if (is.na(value)) return(NA_character_)
    kingdoms <- unique(tolower(trimws(unlist(strsplit(value, ";")))))
    kingdoms <- kingdoms[!kingdoms %in% c(
      "", "na", "n/a", "nodata", "unknown", "unassigned", "unresolved"
    )]
    if (length(kingdoms) != 1L || !grepl("^[a-z]+$", kingdoms)) {
      return(NA_character_)
    }
    paste0(toupper(substr(kingdoms, 1, 1)), substring(kingdoms, 2))
  }, character(1), USE.NAMES = FALSE)
  missing <- is.na(reviewed)
  reviewed[missing] <- source[missing]
  reviewed
}

griis <- prepare_dataset(
  read_standardised(input$griis_clean, "GRIIS")
)
first_records <- prepare_dataset(
  read_standardised(input$first_records_clean, "FirstRecords")
)
national <- NULL
national_path <- input$national_clean
if (length(national_path) > 1L) stop("Supply only one cleaned national checklist.")
if (length(national_path) == 1L && !is.na(national_path) &&
    nzchar(trimws(national_path))) {
  national <- prepare_dataset(
    read_standardised(national_path, "NationalChecklist")
  )
  if (nrow(national) == 0L) {
    stop("No national checklist records have a resolved location. Review preparation exclusions.")
  }
}
datasets <- list(GRIIS = griis, FirstRecords = first_records)
if (!is.null(national)) datasets$NationalChecklist <- national
cleaning_report <- read_report(input$cleaning_summary, "Preparation summary")
qc_report <- read_report(input$qc_status, "Quality-control status")
unmatched_report <- read_report(input$unmatched_values, "Unmatched values")
full_taxa_list <- read_report(input$full_taxa_list, "Full taxonomic list")

required_identity_columns <- c(
  "location", "locationID", "taxon", "scientificName", "taxonID"
)
for (dataset in datasets) {
  missing_identity <- setdiff(required_identity_columns, names(dataset))
  if (length(missing_identity) > 0) {
    stop(
      "A standardised merge input is missing required identity columns: ",
      paste(missing_identity, collapse = ", ")
    )
  }
}

all_columns <- unique(unlist(lapply(datasets, names), use.names = FALSE))
add_missing_columns <- function(dat, columns) {
  for (column in setdiff(columns, names(dat))) {
    dat[[column]] <- rep(NA_character_, nrow(dat))
  }
  dat[, columns, drop = FALSE]
}

combined <- do.call(rbind, lapply(datasets, add_missing_columns, columns = all_columns))
external_records_not_selected <- 0L
if (!is.null(national)) {
  # National rows come first so their reviewed identity is retained.
  combined <- combined[order(combined$origDB != "NationalChecklist"), , drop = FALSE]
  is_national <- combined$origDB == "NationalChecklist"
  ids <- normalise_missing(combined$taxonID)
  names_standardised <- normalise_missing(combined$taxon)
  if (any(is_national & is.na(ids) & is.na(names_standardised))) {
    stop("National records require a standardised taxon ID or taxon name.")
  }
  # Missing IDs never match each other without an exact standardised name.
  identity <- ifelse(!is.na(ids), paste0("id:", ids),
                     paste0("name:", names_standardised))
  combined$nationalMatchKey <- as.character(interaction(
    identity, combined$locationID, drop = TRUE, lex.order = TRUE
  ))
  selected <- combined$nationalMatchKey %in% combined$nationalMatchKey[is_national]
  external_records_not_selected <- sum(!selected)
  combined <- combined[selected, , drop = FALSE]
  is_national <- combined$origDB == "NationalChecklist"
  combined$inNationalChecklist <- is_national
  if (!"eventDate" %in% names(combined)) combined$eventDate <- NA_character_
  years <- suppressWarnings(as.numeric(as.character(combined$eventDate)))
  valid <- is.finite(years) & years == floor(years) & years >= 1 & years <= 9999
  combined$eventDate <- ifelse(valid, as.character(years), NA_character_)
  combined$nationalFirstRecordYear <- ifelse(is_national, combined$eventDate, NA_character_)
  combined$externalFirstRecordYear <- ifelse(!is_national, combined$eventDate, NA_character_)
  combined$firstRecordSource <- ifelse(valid, combined$origDB, NA_character_)
  # Source evidence survives both consolidation passes and identifies conflicts.
  combined$firstRecordEvidence <- ifelse(
    is.na(combined$eventDate), NA_character_,
    paste0(combined$origDB, ": ", combined$eventDate)
  )
}

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

if (!is.null(national)) core_keys <- "nationalMatchKey"

if ("establishmentMeans" %in% names(combined)) {
  core_groups <- make_groups(combined, core_keys)
  for (index in core_groups) {
    values <- normalise_missing(combined$establishmentMeans[index])
    values <- trimws(unlist(strsplit(values[!is.na(values)], ";\\s*")))
    if (all(c("introduced", "uncertain") %in% values)) {
      # Combine only introduced/uncertain records. A native record sharing
      # this identity retains its source status (and a separate row in default mode).
      eligible <- combined$establishmentMeans[index] %in%
        c("introduced", "uncertain", "introduced; uncertain")
      combined$establishmentMeans[index[eligible]] <- "introduced; uncertain"
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
  if (nrow(dat) == 0L) return(dat)
  groups <- make_groups(dat, keys)
  rows <- lapply(groups, function(index) {
    out <- dat[index[1], , drop = FALSE]
    for (column in names(dat)) {
      if (column %in% c("eventDate", "nationalFirstRecordYear", "externalFirstRecordYear")) {
        out[[column]] <- earliest_event_date(dat[[column]][index])
      } else if (column %in% c("uploadedTaxon", "uploadedEventDate")) {
        values <- unique(as.character(dat[[column]][index]))
        values <- values[!is.na(values)]
        out[[column]] <- if (length(values)) paste(values, collapse = "; ") else NA_character_
      } else if (column == "inNationalChecklist") {
        out[[column]] <- any(as.character(dat[[column]][index]) == "TRUE", na.rm = TRUE)
      } else if (column %in% first_columns) {
        out[[column]] <- first_value(dat[[column]][index])
      } else {
        out[[column]] <- combine_values(dat[[column]][index])
      }
    }
    if ("nationalFirstRecordYear" %in% names(out)) {
      national_year <- out$nationalFirstRecordYear
      out$eventDate <- if (!is.na(national_year)) national_year else out$externalFirstRecordYear
      if (!is.na(national_year)) {
        out$firstRecordSource <- "NationalChecklist"
      } else {
        chosen <- !is.na(dat$eventDate[index]) & dat$eventDate[index] == out$eventDate
        chosen[is.na(chosen)] <- FALSE
        out$firstRecordSource <- combine_values(dat$firstRecordSource[index][chosen])
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
if (!is.null(national)) primary_keys <- "nationalMatchKey"
national_identity_columns <- if (!is.null(national)) {
  c("taxon", "scientificName", "taxonID", "location", "locationID")
} else character()
merged_primary <- aggregate_data(combined, primary_keys, national_identity_columns)

## Report fields that disagree before the source workflow's final
## taxon-location-establishment consolidation.
final_keys <- c("taxon", "location", "establishmentMeans")
final_keys <- final_keys[final_keys %in% names(merged_primary)]
if (!is.null(national)) final_keys <- "nationalMatchKey"
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
merged <- aggregate_data(
  merged_primary, final_keys, union(identity_columns, national_identity_columns)
)

if (!is.null(national)) {
  # Report date disagreements before earliest-year aggregation hides them.
  for (index in make_groups(combined, "nationalMatchKey")) {
    years <- unique(normalise_missing(combined$eventDate[index]))
    years <- years[!is.na(years)]
    # Report non-date disagreements too, before national-mode aggregation.
    for (column in intersect(c("establishmentMeans", "occurrenceStatus",
                              "isInvasive", "isInvasiveInCountry", "isInvasiveAnywhere"),
                            names(combined))) {
      values <- unique(normalise_missing(combined[[column]][index]))
      values <- values[!is.na(values)]
      if (length(values) > 1L) {
        merge_conflicts <- rbind(merge_conflicts, data.frame(
          taxon = first_value(combined$taxon[index]),
          location = first_value(combined$location[index]),
          establishmentMeans = combine_values(combined$establishmentMeans[index]),
          column = column, values = paste(values, collapse = " | "),
          stringsAsFactors = FALSE
        ))
      }
    }
    if (length(years) > 1L) {
      merge_conflicts <- rbind(merge_conflicts, data.frame(
        taxon = first_value(combined$taxon[index]),
        location = first_value(combined$location[index]),
        establishmentMeans = combine_values(combined$establishmentMeans[index]),
        column = "eventDate",
        values = combine_values(combined$firstRecordEvidence[index]),
        stringsAsFactors = FALSE
      ))
    }
  }
}

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
if (nrow(taxonomy) == 0 && is.null(national)) {
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
if (length(taxonomy_groups) > 0L) taxonomy <- do.call(rbind, lapply(taxonomy_groups, function(index) {
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
if ("Kingdom_user" %in% names(merged)) {
  # A source kingdom remains useful even when the name has no reviewed match.
  # This does not resolve the taxon or supply any missing lower ranks.
  merged$kingdom <- kingdom_with_source_fallback(
    merged$kingdom, merged$Kingdom_user
  )
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
if (!is.null(national)) {
  output_columns <- c(output_columns, "inNationalChecklist", "nationalFirstRecordYear",
    "externalFirstRecordYear", "firstRecordSource", "firstRecordEvidence",
    "sourceRow", "uploadedTaxon", "uploadedEventDate")
}
merged <- merged[, intersect(output_columns, names(merged)), drop = FALSE]

summary <- data.frame(
  country = country_name,
  ISO3 = country_iso3,
  source = c(names(datasets), "Merged"),
  records = c(vapply(datasets, nrow, integer(1)), nrow(merged)),
  merge_conflicts = c(rep(NA_integer_, length(datasets)), nrow(merge_conflicts)),
  stringsAsFactors = FALSE
)

if (!is.null(national)) {
  summary$external_records_not_selected <- c(rep(NA_integer_, length(datasets)),
                                              external_records_not_selected)
}

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

date_conflict <- conflict_rows_report$field == "eventDate"
conflict_rows_report$details[date_conflict] <- "First-record years disagree across or within sources"
conflict_rows_report$action[date_conflict] <- paste(
  "Earliest valid national year takes precedence; otherwise earliest external year.",
  "All dated source evidence is retained in firstRecordEvidence."
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
if (!is.null(national) && nrow(merge_conflicts) > 0L) overall_qc <- "WARNING"

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
  input_records = sum(vapply(datasets, nrow, integer(1))),
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
