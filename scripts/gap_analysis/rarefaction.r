library(duckdb)
library(iNEXT)

con <- dbConnect(duckdb::duckdb(), dbdir = ":memory:")

input <- biab_inputs()
occurrences <- input$occurrences

dbExecute(con, paste0(
  "CREATE VIEW gbif AS SELECT * FROM read_csv_auto('", occurrences, "')"
))


groups <- list(
  "Amphibia" = "Class",
  "Reptilia" = "Class",
  "Mammalia" = "Class",
  "Arthropoda" = "Phylum",
  "Aves" = "Class",
  "Actinopterygii" = "Class"
)

summary <- data.frame(group_name=character(),
                      species=character(),
                      first_observed=integer(),
                      total_obs=integer())

for (group in names(groups)) {
  rank <- groups[[group]]
  summ <- get_species_summary(con, group, rank)
  summary <- rbind(summary, summ)
}

rarefaction <- list()
for (group in names(groups)) {
  rarefaction[[group]] <- rbind(rarefaction,
  iNEXT::iNEXT(summary |> filter(group_name == group), 
  q = 0, datatype = "abundance"))
}



get_species_summary <- function(con, taxonomic_group, rank) {
  taxo <- paste(paste0('"',taxonomic_group,'"'),collapse=',')
  query <- paste0("
    SELECT
        ",rank," AS group_name,
        species,
        MIN(year) AS first_observed,
        COUNT(*) AS total_obs
    FROM gbif
    WHERE taxonRank IN ('SPECIES', 'SUBSPECIES')
      AND (
            ",rank," IN (", taxonomic_group, ")
          )
      AND year IS NOT NULL
    GROUP BY ",rank,", species
    ORDER BY species
  ")

  dbGetQuery(con, query)
}


get_richness_summary <- function(con, taxonomic_group, rank) {
  taxo <- paste(paste0('"',taxonomic_group,'"'),collapse=',')
  query <- paste0("
    SELECT
        ",rank," AS group_name,
        year,
        count(DISTINCT species) AS richness,
    FROM gbif
    WHERE taxonRank IN ('SPECIES', 'SUBSPECIES')
      AND (
            ",rank," IN (", taxonomic_group, ")
          )
      AND year IS NOT NULL
    GROUP BY ",rank,", year
  ")

  dbGetQuery(con, query)
}