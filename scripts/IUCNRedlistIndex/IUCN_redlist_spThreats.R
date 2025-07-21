## Load libraries ###
packagesList <- list("magrittr")
lapply(packagesList, library, character.only = TRUE)

input <- biab_inputs()

threats <- input$threat_category_input
biab_output("threat_category", threats)


if ("Do not filter by threat category" %in% threats) {
    if (length(threats) > 1) {
        biab_error_stop("Cannot select more than one option when selecting 'Do not filter by threat category'")
    }
    IUCN_threats <- data.frame()
    iucn_threats_splist_path <- file.path(outputFolder, paste0("iucn_threats_splist", ".csv")) # Define the file path
    write.csv(IUCN_threats, iucn_threats_splist_path, row.names = F) # write result
    biab_output("iucn_threats_splist", iucn_threats_splist_path)

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
    threats_list_path <- file.path(outputFolder, paste0("threats_list", ".csv")) # Define the file path
    write.csv(IUCN_threats, threats_list_path, row.names = F) # write result

    biab_output("threats_list", threats_list_path)

    species_threats <- data.frame()
    for (threat in threats) { # loop through each threat category
        print(sprintf("Loading species for '%s' threat category...", threat))
        IUCN_threatcode_group <- IUCN_threats$threats$code[IUCN_threats$threats$description$en == threat]
        print(IUCN_threatcode_group)
        IUCN_threatcode <- IUCN_threats$threats$code[grepl(paste0("^", IUCN_threatcode_group, "(_|$)"), IUCN_threats$threats$code)]
        print(IUCN_threatcode)

        IUCN_threatcode_results_all <- data.frame()
        for (code in IUCN_threatcode) { # loop through each threatcode in the larger category
            IUCN_threatcode_results <- rredlist::rl_threats(code = code, key = token)$assessments
            IUCN_threatcode_results$threatcode <- code
            print(head(IUCN_threatcode_results))
            if (length(IUCN_threatcode_results_all) == 0) {
                IUCN_threatcode_results_all <- IUCN_threatcode_results
            } else {
                if (is.data.frame(IUCN_threatcode_results)) {
                    IUCN_threatcode_results_all <- rbind(IUCN_threatcode_results_all, IUCN_threatcode_results)
                }
                else {
                    print("SKIPPING*************")
                    print(sprintf("Code is %s", code))
                }
            }
        }
        if (nrow(species_threats) == 0) {
            species_threats <- IUCN_threatcode_results_all
        } else {
            species_threats <- rbind(species_threats, IUCN_threatcode_results_all)
        }
    }


    if (nrow(species_threats) == 0) {
        biab_error_stop("Could not find any species in the threat category")
    }
    # Output list of species with that threat
    species_threats$scopes <- sapply(species_threats$scopes, function(x) paste(unlist(x), collapse = ", "))
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
