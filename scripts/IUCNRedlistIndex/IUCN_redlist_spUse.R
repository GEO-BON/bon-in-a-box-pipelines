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

uses <- input$species_use

if (length(uses) == 0) {
  biab_error_stop("Please select a species use")
}

biab_output("species_use", uses)

skip <- FALSE
if ("Do not filter by species use or trade" %in% uses) {
  if (length(uses) > 1) {
    biab_error_stop("Cannot select more than one option when selecting 'Don't filter by species use'")
  }
  skip <- TRUE

  IUCN_use <- data.frame()
  iucn_use_splist_path <- file.path(outputFolder, paste0("iucn_use_splist", ".csv")) # Define the file path
  write.csv(IUCN_use, iucn_use_splist_path, row.names = F) # write result
  biab_output("iucn_use_splist", iucn_use_splist_path)

  citation <- "No data retrieved based on use and trade, as selected by the user"
  biab_output("api_citation", citation)
}

if (skip == FALSE) {
  if ("All" %in% uses) {
    if (length(uses) > 1) {
      biab_error_stop("Cannot select more than one option when selecting 'All'")
    }

    uses <- c("Food - human", "Food - animal", "Medicine - human & veterinary",
    "Poisons", "Manufacturing chemicals", "Other chemicals", "Fuels", "Fibre",
    "Construction or structural materials", "Wearing apparel, accessories",
    "Other household goods", "Handicrafts, jewellery, etc.", "Pets/display animals, horticulture",
    "Research", "Sport hunting/specimen collecting", "Establishing ex-situ production *",
    "Other (free text)", "Unknown")
  }

  IUCN_uses <- rredlist::rl_use_and_trade(key = token)
  IUCN_use_splist <- data.frame()

  for (use in uses) {

    if (use == "Other") {
      use <- "Other (free text)"
    }
    if (use == "Establishing ex-situ production") {
      use <- "Establishing ex-situ production *"
    }

    IUCN_code <- IUCN_uses$use_and_trade$code[IUCN_uses$use_and_trade$description$en == use]
    print(sprintf("Loading species for %s...", use))
    IUCN_use <- rredlist::rl_use_and_trade(code = IUCN_code, key = token, latest = TRUE, scope_code = 1)$assessments

    if (nrow(IUCN_use) > 0) {
      IUCN_use$use <- use
      IUCN_use_splist <- rbind(IUCN_use_splist, IUCN_use)
    }
  }

  print(sprintf("Number of species found: %s", nrow(IUCN_use_splist)))

  IUCN_use_splist$scopes <- sapply(IUCN_use_splist$scopes, function(x) paste(unlist(x), collapse = ", "))
  IUCN_use_path <- file.path(outputFolder, paste0("IUCN_use_splist", ".csv")) # Define the file path
  write.csv(IUCN_use_splist, IUCN_use_path, row.names = F) # write result

  biab_output("iucn_use_splist", IUCN_use_path)

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
