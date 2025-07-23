## Load libraries ###
packagesList <- list("magrittr") # Explicitly list packages needed that must be fully loaded in the environment. Functions from other libraries will be accessible via '::'.
lapply(packagesList, library, character.only = TRUE) # Load explicitly listed libraries

input <- biab_inputs()

groups <- input$taxonomic_group

biab_output("taxonomic_group", groups)

groups <- tolower(gsub(" ", "_", groups))

all <- FALSE

# If all is selected, skip this script
if ("all" %in% groups) {
  if (length(groups) > 1) {
    biab_error_stop("Cannot select more than one option when selecting 'All'")
  }

  all <- TRUE

  IUCN_taxon <- data.frame()
  iucn_taxon_splist_path <- file.path(outputFolder, paste0("iucn_taxon_splist", ".csv")) # Define the file path
  write.csv(IUCN_taxon, iucn_taxon_splist_path, row.names = F) # write result
  biab_output("iucn_taxon_splist", iucn_taxon_splist_path)

  citation <- "No data retrieved for specific taxon group because user selected `All`"
  biab_output("api_citation", citation)
}

if (all == FALSE) {
  # Script body ####
  token <- Sys.getenv("IUCN_TOKEN")
  if (token == "") {
    biab_error_stop("Please specify an IUCN token in your environment file")
  }
  print(token)

  IUCN_taxon_all <- data.frame()

  for (group in groups) {
    ## Load sp taxonomic group ####
    print(sprintf("Loading species for '%s' taxon group...", group))
    IUCN_taxon <- rredlist::rl_comp_groups(name = group, key = token)$assessments

    if (nrow(IUCN_taxon) > 0) {
      IUCN_taxon_all <- rbind(IUCN_taxon_all, IUCN_taxon)
    }
  }

  IUCN_taxon_all$scopes <- sapply(IUCN_taxon_all$scopes, function(x) paste(unlist(x), collapse = ", "))
  iucn_taxon_splist_path <- file.path(outputFolder, paste0("iucn_taxon_splist", ".csv")) # Define the file path
  write.csv(IUCN_taxon_all, iucn_taxon_splist_path, row.names = F) # write result

  biab_output("iucn_taxon_splist", iucn_taxon_splist_path)

  citation <- rredlist::rl_citation(key = token)

  # Extract citation
  citation <- capture.output(print(citation))
  lines <- trimws(unlist(strsplit(citation, "\n")))
  start <- grep("^IUCN \\([0-9]{4}\\)", lines)
  end <- grep("Accessed on", lines)
  end <- end[end >= start][1]

  citation <- paste(lines[start:end], collapse = " ")

  biab_output("api_citation", citation)
}