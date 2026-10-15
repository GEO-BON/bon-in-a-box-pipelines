## ------------------------------------------------------
## Extract covariate data from GBIF using an SQL download.
## Adapted for BON in a Box from the original SInAS SQL method.
## ------------------------------------------------------

library(rgbif)
library(countrycode)
library(readr)
library(rjson)

input <- biab_inputs()

start_year <- suppressWarnings(as.integer(input$start_year))
end_year <- suppressWarnings(as.integer(input$end_year))
country_name <- input$country_name$country$englishName
country_iso3_raw <- input$country_name$country$ISO3
country_iso3 <- if (is.null(country_iso3_raw)) {
  NA_character_
} else {
  sub("_.*$", "", toupper(trimws(as.character(country_iso3_raw))))
}

if (is.na(start_year) || is.na(end_year)) {
  biab_error_stop("Start year and end year must both be valid integers.")
}
if (end_year < start_year) {
  biab_error_stop("End year must be greater than or equal to start year.")
}
if (is.null(country_name) || !nzchar(country_name)) {
  biab_error_stop("Please specify a country.")
}
if (length(country_iso3) != 1 || is.na(country_iso3) ||
    !grepl("^[A-Z]{3}$", country_iso3)) {
  biab_error_stop("The selected country must provide a valid ISO3 code.")
}

country_iso2 <- countrycode::countrycode(
  country_iso3, origin = "iso3c", destination = "iso2c"
)
if (is.na(country_iso2)) {
  biab_error_stop(
    paste0("No ISO2 code found for ISO3 code '", country_iso3, "'.")
  )
}

gbif_user <- Sys.getenv("GBIF_USER")
gbif_password <- Sys.getenv("GBIF_PWD")
gbif_email <- Sys.getenv("GBIF_EMAIL")
if (any(!nzchar(c(gbif_user, gbif_password, gbif_email)))) {
  biab_error_stop(
    paste0(
      "GBIF_USER, GBIF_PWD, and GBIF_EMAIL must be added to the runner.env file to use ",
      "the GBIF SQL download service."
    )
  )
}

message("Requesting GBIF SQL counts for ", country_name, " (", country_iso3, ")")

## start_year and end_year are R values. They must be inserted into the SQL
## string; otherwise GBIF interprets their names as occurrence-table columns.
sql <- paste0(
  "SELECT \"year\", COUNT(*) AS RecordsCount\n",
  "FROM occurrence\n",
  "WHERE \"year\" >= ", start_year, "\n",
  "  AND \"year\" <= ", end_year, "\n",
  "  AND level0gid = '", country_iso3, "'\n",
  "  AND countrycode = '", country_iso2, "'\n",
  "  AND (kingdom = 'Plantae' OR kingdom = 'Animalia')\n",
  "  AND (basisOfRecord = 'OBSERVATION'\n",
  "    OR basisOfRecord = 'LIVING_SPECIMEN'\n",
  "    OR basisOfRecord = 'MATERIAL_SAMPLE'\n",
  "    OR basisOfRecord = 'HUMAN_OBSERVATION'\n",
  "    OR basisOfRecord = 'MACHINE_OBSERVATION'\n",
  "    OR basisOfRecord = 'OCCURRENCE')\n",
  "  AND occurrenceStatus = 'PRESENT'\n",
  "  AND decimalLongitude IS NOT NULL\n",
  "  AND decimalLatitude IS NOT NULL\n",
  "  AND NOT ARRAY_CONTAINS(issue, 'COORDINATE_INVALID')\n",
  "  AND NOT ARRAY_CONTAINS(issue, 'ZERO_COORDINATE')\n",
  "  AND NOT ARRAY_CONTAINS(issue, 'COORDINATE_OUT_OF_RANGE')\n",
  "  AND NOT ARRAY_CONTAINS(issue, 'COUNTRY_COORDINATE_MISMATCH')\n",
  "GROUP BY \"year\"\n",
  "ORDER BY \"year\""
)

download_request <- rgbif::occ_download_sql(
  q = sql,
  user = gbif_user,
  pwd = gbif_password,
  email = gbif_email,
  curlopts = list(http_version = 2L)
)
download_key <- as.character(download_request)
message("GBIF download key: ", download_key)

rgbif::occ_download_wait(
  download_request,
  status_ping = 10,
  curlopts = list(http_version = 2L),
  quiet = FALSE
)

download_archive <- rgbif::occ_download_get(
  download_request,
  path = outputFolder,
  overwrite = TRUE,
  curlopts = list(http_version = 2L)
)
gbif_country_observations <- rgbif::occ_download_import(download_archive)

output_path <- file.path(outputFolder, "gbif_country_observations.csv")
readr::write_csv(gbif_country_observations, output_path, na = "")
biab_output("gbif_country_observations", output_path)
