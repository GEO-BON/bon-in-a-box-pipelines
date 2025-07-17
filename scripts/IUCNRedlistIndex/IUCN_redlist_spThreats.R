## Load libraries ###
packagesList <- list("magrittr")
lapply(packagesList, library, character.only = TRUE)

input <- biab_inputs()

threat <- input$threat_category
biab_output("threat_category", threat)


if ("Do not filter by threat category" %in% threat) {
    if (length(threat)>1){
        biab_error_stop("Cannot select more than one option when selecting 'Do not filter by threat category'")
    }
    IUCN_threats <- data.frame()
    iucn_threats_splist_path <- file.path(outputFolder, paste0("iucn_threats_splist", ".csv")) # Define the file path
    write.csv(IUCN_threats, iucn_threats_splist_path, row.names = F) # write result
    biab_output("iucn_threats_splist", iucn_taxon_splist_path)

    citation <- "No threat data retrieved because user selected `don't filter by threat category'"
    biab_output("api_citation", citation)
} else {

    token <- Sys.getenv("IUCN_TOKEN")
    if (token == "") {
        biab_error_stop("Please specify an IUCN token in your environment file")
    }
    print(token)



    ## Select threat groups for each threat input
    IUCN_threats <- rredlist::rl_threats(key = token)
    IUCN_threatcode <- IUCN_threats$threats$code[IUCN_threats$threats$description$en == threat]
 
    species_threats <- c()
    for (i in seq_along(threat)) {
        print(sprintf("Loading species for '%s' threat category...", threat))
        IUCN_threatcode <- IUCN_threatcode[i]
        print(IUCN_threatcode)
        IUCN_threatcode_results <- rredlist::rl_threats(code = IUCN_threatcode, key = token)$assessments
        
        if (is.null(IUCN_threatcode_results) | nrow(IUCN_threatcode_results) == 0) {
            print(paste0("Could not find any species in the threat category ", threat, ", skipping"))
            if(length(threat) == 1){
               biab_error_stop("Could not find any species in the threat category")
            }
            next
        }
        print(IUCN_threatcode_results)
        IUCN_threatcode_results$scopes <- sapply(IUCN_threatcode_results$scopes, function(x) paste(unlist(x), collapse = ", "))
        species_threats[[i]] <- IUCN_threatcode_results
    }

    # Output list of species with that threat
    if(length(input$threat_category > 1)){
    species_threats <- do.call(rbind, species_threats)
    }

    IUCN_threats_path <- file.path(outputFolder, paste0("IUCN_threats_splist", ".csv")) # Define the file path
    write.csv(species_threats, IUCN_threats_path, row.names = F) # write result

    biab_output("iucn_threats_splist", IUCN_threats_path)

    # Output citation
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
