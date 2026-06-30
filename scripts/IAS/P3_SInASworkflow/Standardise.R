# This script standardises terms, location names, and taxon names

# inputs

input <- biab_inputs()

# datasets from PrepareDatasets

datasets <- input$datasets

# Standardise terms

StandardiseTerms <- function(FileInfo=NULL){
  
  ## identify input datasets based on file name "StandardSpec_....csv"
  allfiles <- list.files(file.path(workingDirectory, "Output","Intermediate"))
  inputfiles_all <- allfiles[grep("Step1_StandardColumns_",allfiles)]
  inputfiles <- vector()
  for (i in 1:nrow(FileInfo)){
    # inputfiles <- c(inputfiles,grep(FileInfo[i,"Dataset_brief_name"],inputfiles_all,value=T))
    inputfiles <- c(inputfiles,paste("Step1_StandardColumns_",FileInfo[i,"Dataset_brief_name"],".csv",sep=""))
  }
  inputfiles <- inputfiles[!is.na(inputfiles)]
  
  ## translation tables
  translation_estabmeans <- read.xlsx(file.path(config_dir, "Translation_establishmentMeans.xlsx"),sheet=1)
  translation_occurrence <- read.xlsx(file.path(config_dir, "Translation_occurrenceStatus.xlsx"),sheet=1)
  translation_degrEstab <- read.xlsx(file.path(config_dir, "Translation_degreeOfEstablishment.xlsx"),sheet=1)
  translation_pathway <- read.xlsx(file.path(config_dir, "Translation_pathway.xlsx"),sheet=1)
  translation_habitat <- read.xlsx(file.path(config_dir, "Translation_habitat.xlsx"),sheet=1)
  
  for (i in 1:length(inputfiles)){#
    
    dat <- read.table(file.path(workingDirectory,"Output","Intermediate",inputfiles[i]),header=T,stringsAsFactors = F)
    
    unresolved_estabmeans <- vector()
    unresolved_occurrenceStatus <- vector()
    unresolved_degreeOfEstablishment <- vector()
    unresolved_pathway <- vector()
    unresolved_habitat <- vector()
    resolved_estabmeans <- vector()
    resolved_occurrenceStatus <- vector()
    resolved_degreeOfEstablishment <- vector()
    resolved_pathway <- vector()
    resolved_habitat <- vector()
    
    ## Darwin Core: establishmentMeans
    if (any(colnames(dat)=="establishmentMeans")){
      dat$establishmentMeans <- gsub("^\\s+|\\s+$", "",dat$establishmentMeans) # trim leading and trailing whitespace
      # identify matches of alternative terms...
      ind <- match(tolower(dat$establishmentMeans),tolower(translation_estabmeans$origTerm)) # identify matches
      unresolved_estabmeans <- unique(dat$establishmentMeans[is.na(ind)]) # store mis-matches
      resolved_estabmeans <- unique(dat$establishmentMeans[!is.na(ind)]) # store mis-matches
      translated <- translation_estabmeans$newTerm[ind]
      indNA <- is.na(translated)
      dat$establishmentMeans[!indNA] <- translated[!indNA]  # replace strings
      # identify matches of Darwin Core
      ind <- match(tolower(dat$establishmentMeans),tolower(translation_estabmeans$newTerm)) # identify matches with Darwin Core
      dat$establishmentMeans <- translation_estabmeans$newTerm[ind] # replace strings
      dat$establishmentMeans[is.na(ind)] <- "" # indicate mis-matches
    }

    ## Darwin Core: occurrenceStatus
    if (any(colnames(dat)=="occurrenceStatus")){
      dat$occurrenceStatus <- gsub("^\\s+|\\s+$", "",dat$occurrenceStatus) # trim leading and trailing whitespace
      # identify matches of alternative terms...
      ind <- match(tolower(dat$occurrenceStatus),tolower(translation_occurrence$origTerm)) # identify matches
      unresolved_occurrenceStatus <- unique(dat$occurrenceStatus[is.na(ind)]) # store mis-matches
      resolved_occurrenceStatus <- unique(dat$occurrenceStatus[!is.na(ind)]) # store mis-matches
      translated <- translation_occurrence$newTerm[ind]
      indNA <- is.na(translated)
      dat$occurrenceStatus[!indNA] <- translated[!indNA]  # replace strings
      # identify matches of Darwin Core
      dat$occurrenceStatus[dat$occurrenceStatus!="absent"] <- "present" # Assumption (!) that all species are present if not listed otherwise
    }
    
    ## Darwin Core: degreeOfEstablishment (not officially accepted by Darwin Core)
    if (any(colnames(dat)=="degreeOfEstablishment")){
      dat$degreeOfEstablishment <- gsub("^\\s+|\\s+$", "",dat$degreeOfEstablishment) # trim leading and trailing whitespace
      # identify matches of alternative terms...
      ind <- match(tolower(dat$degreeOfEstablishment),tolower(translation_degrEstab$origTerm)) # identify matches of translated terms
      unresolved_degreeOfEstablishment <- unique(dat$degreeOfEstablishment[is.na(ind)]) # store mis-matches
      resolved_degreeOfEstablishment <- unique(dat$degreeOfEstablishment[!is.na(ind)]) # store mis-matches
      translated <- translation_degrEstab$newTerm[ind]
      indNA <- is.na(translated)
      dat$degreeOfEstablishment[!indNA] <- translated[!indNA]  # replace strings
      # identify matches of Darwin Core
      ind <- match(tolower(dat$degreeOfEstablishment),tolower(translation_degrEstab$newTerm)) # identify matches with Darwin Core
      dat$degreeOfEstablishment <- translation_degrEstab$newTerm[ind] # replace strings
      dat$degreeOfEstablishment[is.na(ind)] <- "" # indicate mis-matches
    }
    
    ## Darwin Core: pathway
    if (any(colnames(dat)=="pathway")){
      dat$pathway <- gsub("^\\s+|\\s+$", "",dat$pathway) # trim leading and trailing whitespace
      # identify matches of alternative terms...
      ind <- match(tolower(dat$pathway),tolower(translation_pathway$origTerm)) # identify matches of translated terms
      unresolved_pathway <- unique(dat$pathway[is.na(ind)]) # store mis-matches
      resolved_pathway <- unique(dat$pathway[!is.na(ind)]) # store mis-matches
      translated <- translation_pathway$newTerm[ind]
      indNA <- is.na(translated)
      dat$pathway[!indNA] <- translated[!indNA]  # replace strings
      # identify matches of Darwin Core
      ind <- match(tolower(dat$pathway),tolower(translation_pathway$newTerm)) # identify matches with Darwin Core
      dat$pathway <- translation_pathway$newTerm[ind] # replace strings
      dat$pathway[is.na(ind)] <- "" # indicate mis-matches
    }
    
    ## Darwin Core: habitat
    if (any(colnames(dat)=="habitat")){
      dat$habitat <- gsub("^\\s+|\\s+$", "",dat$habitat) # trim leading and trailing whitespace
      # identify matches of alternative terms...
      ind <- match(tolower(dat$habitat),tolower(translation_habitat$origTerm)) # identify matches of translated terms
      unresolved_habitat <- unique(dat$habitat[is.na(ind)]) # store mis-matches
      resolved_habitat <- unique(dat$habitat[!is.na(ind)]) # store matches
      translated <- translation_habitat$newTerm[ind]
      indNA <- is.na(translated)
      dat$habitat[!indNA] <- translated[!indNA]  # replace strings
      # identify matches of Darwin Core
      ind <- match(tolower(dat$habitat),tolower(translation_habitat$newTerm)) # identify matches with Darwin Core
      dat$habitat <- translation_habitat$newTerm[ind] # replace strings
      dat$habitat[is.na(ind)] <- "" # indicate mis-matches
    }
    
    
    ## Output ###########################
    
    all_unresolved <- unique(c(unresolved_estabmeans,unresolved_occurrenceStatus,unresolved_degreeOfEstablishment,unresolved_pathway))
    all_unresolved <- all_unresolved[!all_unresolved%in%resolved_estabmeans] 
    all_unresolved <- all_unresolved[!all_unresolved%in%resolved_occurrenceStatus] 
    all_unresolved <- all_unresolved[!all_unresolved%in%resolved_degreeOfEstablishment] 
    all_unresolved <- all_unresolved[!all_unresolved%in%resolved_pathway] 
    all_unresolved <- all_unresolved[!all_unresolved%in%resolved_habitat] 
    
    if (length(all_unresolved)>0){ # output mis-matches for reference
      write.table(all_unresolved,file.path(workingDirectory,"Output","Check",paste0("Unresolved_Terms_",FileInfo[i,"Dataset_brief_name"],".csv")),row.names=F,col.names=F)
      cat(paste0("\n    Warning: Unresolved terms in ",FileInfo[i,"Dataset_brief_name"],". Check file UnresolvedTerms_* in subfolder Check/ \n"))
    }
    
    write.table(dat,file.path(workingDirectory,"Output","Intermediate",paste0("Step2_StandardTerms_",FileInfo[i,"Dataset_brief_name"],".csv")),row.names=F)
    
  }
}


# Standardise location names

StandardiseLocationNames <- function(FileInfo=NULL){
  
  ## identify input datasets based on file name "StandardSpec_....csv"
  allfiles <- list.files(file.path(workingDirectory,"Output","Intermediate"))
  inputfiles_all <- allfiles[grep("Step2_StandardTerms_",allfiles)]
  inputfiles <- vector()
  for (i in 1:nrow(FileInfo)){
    # inputfiles <- c(inputfiles,grep(FileInfo[i,"Dataset_brief_name"],inputfiles_all,value=T))
    inputfiles <- c(inputfiles,paste("Step2_StandardTerms_",FileInfo[i,"Dataset_brief_name"],".csv",sep=""))
  }
  inputfiles <- inputfiles[!is.na(inputfiles)]
  
  ## load location tables #################################################
  # load table with countries (i.e. regions)
  regions <- read.xlsx(file.path(config_dir, "AllLocations.xlsx"), sheet = 2, na.strings = "") # Sheet with first aggregation level (i.e. countries)
  regions <- regions[, c("locationID", "location", "location_var")]
  regions$location_var <- tolower(regions$location_var)  # Set all to lowercase for matching
  regions$location_lower <- tolower(regions$location)  # Set all to lowercase for matching
  
  # load table with state, provinces, departments, etc... (i.e. subregions)
  subregions <- read.xlsx(file.path(config_dir, "AllLocations.xlsx"), sheet = 3, na.strings = "") # Sheet with second aggregation level (i.e. states, provinces...)
  subregions <- subregions[, c("locationID", "location", "location_var", "gadm1_name", "gadm1_var")]
  subregions$gadm1_var <- tolower(subregions$gadm1_var)  # Set all to lowercase for matching
  subregions$Gadm1_lower <- tolower(subregions$gadm1_name)  # Set all to lowercase for matching
  
  # Get duplicated names of subregions  
  dup <- unique(gsub("\\s*\\(.*?\\)", "", subregions$gadm1_name)[duplicated(gsub("\\s*\\(.*?\\)", "", subregions$gadm1_name))])
  
  ## loop over all data set ############################################
  for (i in 1:length(inputfiles)){
    
    dat <- read.table(file.path(workingDirectory,"Output","Intermediate",paste0(inputfiles[i])),header=T,stringsAsFactors = F)
    
    # dat <- dat[dat$GBIFstatus!="Missing",]
    #   print(inputfiles[i])
    #   print(dim(dat))
    #   print(length(unique(dat$Species_name_orig)))
    #   print(length(unique(dat$location_orig)))
    # }
    
    # Prepare for matching with regions
    dat_match1 <- dat ## use another dat set for region matching to keep the original names
    dat_match1$order <- 1:nrow(dat_match1)
    dat_match1$location_orig <- gsub("\\xa0|\\xc2", " ", dat_match1$location_orig)  # Replace special spaces
    dat_match1$location_orig <- gsub("^\\s+|\\s+$", "", dat_match1$location_orig)  # Trim leading/trailing whitespace
    dat_match1$location_orig <- gsub("  ", " ", dat_match1$location_orig)  # Replace double spaces
    dat_match1$location_orig <- gsub(" \\(the\\)", "", dat_match1$location_orig)  # Remove " (the)"
    dat_match1$location_lower <- tolower(dat_match1$location_orig)  # Lowercase for matching
    
    ## Step 1: Match names of 'dat' with region names of 'regions' and 'subregions' 
    dat_match_regions <- merge(dat_match1, regions, by.x = "location_lower", by.y = "location_lower", all.x = TRUE)
    dat_match_subregions <- merge(dat_match1, subregions, by.x = "location_lower", by.y = "Gadm1_lower", all.x = TRUE)
    
    ## Step 2a: Match based on keywords in 'regions' - after "location_var" column
    ind_keys_regions <- which(!is.na(regions$location_var))
    for (j in ind_keys_regions) {  # loop over rows with multiple country name variations
      location_var <- unlist(strsplit(regions$location_var[j], "; ")) # check if multiple country name variations provided
      for (k in location_var) {
        ind_match <- which(dat_match_regions$location_lower == k)
        if (length(unique(regions$location[j])) > 1) 
          cat(paste0("Warning: ", k, " matches multiple location names. Refine location_var!"))
        
        dat_match_regions$location[ind_match] <- regions$location[j]
        dat_match_regions$locationID[ind_match] <- regions$locationID[j]
      }
    }
    
    ## Step 2b: Match based on keywords in 'subregions' - after "gadm1_var" column
    ind_keys_subregions <- which(!is.na(subregions$gadm1_var))
    for (j in ind_keys_subregions) {  # loop over rows with multiple subregion name variations
      gadm1_var <- unlist(strsplit(subregions$gadm1_var[j], "; ")) # check if multiple subregion name variations provided
      for (k in gadm1_var) {
        ind_match <- which(dat_match_subregions$location_lower == k)
        if (length(unique(subregions$gadm1_name[j])) > 1) 
          cat(paste0("Warning: ", k, " matches multiple location names. Refine gadm1_var!"))
        
        dat_match_subregions$gadm1_name[ind_match] <- subregions$gadm1_name[j]
        dat_match_subregions$location[ind_match] <- subregions$location[j]
        dat_match_subregions$locationID[ind_match] <- subregions$locationID[j]
      }
    }
    
    ## Merge both data frames with standardized locations names ('region' and 'subregion')
    dat_match1 <- full_join(dat_match_subregions, 
                            dat_match_regions |> dplyr::select(order, locationID, location), 
                            by="order") |> 
      mutate(locationID = coalesce(locationID.x, locationID.y),
             location = coalesce(location.x, location.y))|> 
      dplyr::select(-locationID.x, -locationID.y, -location.x, -location.y, -location_var, -gadm1_var)
    
    
    ## final merging of both data sets with standardized region names to original data
    dat_match1 <- dat_match1[order(dat_match1$order),]
    if (!identical(dat_match1$taxon_orig,dat$taxon_orig)) stop("Data sets not sorted equally!")
    
    dat$locationID <- dat_match1$locationID
    dat$location <- dat_match1$location
    dat$stateProvince <- dat_match1$gadm1_name
    
    ## Check if any locations in the original dataframe correspond to duplicated locations in the world. 
    if (any(dat$location_orig %in% dup)) {
      # Extract the matching names from dat$location_orig
      matching_names <- unique(dat$location_orig[dat$location_orig %in% dup])
      warning(paste(
        "\n    Warning: Unresolved terms in ",FileInfo[i,"Dataset_brief_name"],".The following location name(s) correspond to multiple subregions in the world:",
        paste(matching_names, collapse = ", "),
        ". Please modify the original location name(s) by including the country name in parentheses(), and try again (e.g: Amazonas (Colombia)) \n"
        ))
    }
    
    #dat_regnames <- merge(dat,regions[,c("locationID","location")],by.x="region",by.y="location",all.x=T)
    dat_regnames <- dat
    
    ## Remove duplicated entries
    dat_regnames <- dat_regnames[!duplicated(dat_regnames), ]
    write_regnames <- dat_regnames
    
    # Clean locations and locationID 
    write_regnames <- write_regnames |> 
      dplyr::select(-c(stateProvince, locationID)) |> 
      left_join(regions |> dplyr::select(location, locationID), by = "location")

    
    ## output ###############################################################################
    
    # Output: Save the file with standardized location names
    write.table(write_regnames,file.path(workingDirectory,"Output","Intermediate",paste0("Step3_StandardLocationNames_",FileInfo[i,"Dataset_brief_name"],".csv")),row.names=F)
    
    # Check and export missing locations
    missing <- dat_regnames$location_orig[is.na(dat_regnames$locationID)]
    if (length(missing) > 0) {
      write.table(sort(unique(missing)),file.path(workingDirectory,"Output","Check",paste0("Missing_Locations_",FileInfo[i,"Dataset_brief_name"],".csv")),row.names = F,col.names=F)
    }
  }
  
  ## Post-processing: Aggregate and export changed location names
  if (nrow(dat_regnames)>0){ # avoid step when no region names have changed
    reg_names <- vector()
    for (i in 1:length(inputfiles)){
      dat <- read.table(file.path(workingDirectory,"Output","Intermediate",paste0("Step3_StandardLocationNames_",FileInfo[i,"Dataset_brief_name"],".csv")),stringsAsFactors = F,header=T)
      reg_names <- rbind(reg_names,cbind(dat[,c("location","location_orig")],FileInfo[i,1]))
    }
    reg_names <- reg_names[reg_names$location!=reg_names$location_orig,] # export only region names deviating from the original
    reg_names <- unique(reg_names[order(reg_names$location),])
    colnames(reg_names) <- c("location","location_orig","origDB")
    
    # Clean locations and locationID 
    reg_names  <- reg_names |> left_join(regions |> dplyr::select(location, locationID), by = "location")
    
    write.table(reg_names,file.path(workingDirectory,"Output","Translated_LocationNames.csv"),row.names=F)
  }
}

# Standardise taxon names

StandardiseTaxonNames <- function(FileInfo=NULL){

  ## identify input datasets based on file name "StandardColumns_....csv"
  allfiles <- list.files(file.path(workingDirectory,"Output","Intermediate"))
  inputfiles_all <- allfiles[grep("Step3_StandardLocationNames_",allfiles)]
  inputfiles <- vector()
  for (i in 1:nrow(FileInfo)){
    # inputfiles <- c(inputfiles,grep(FileInfo[i,"Dataset_brief_name"],inputfiles_all,value=T))
    inputfiles <- c(inputfiles,paste("Step3_StandardLocationNames_",FileInfo[i,"Dataset_brief_name"],".csv",sep=""))
  }
  inputfiles <- inputfiles[!is.na(inputfiles)]
  

  ## loop over all data sets ################################################
  fullspeclist <- vector()
  for (i in 1:length(inputfiles)){ # loop over inputfiles 
    
    dat <- read.table(file.path(workingDirectory,"Output","Intermediate",paste0(inputfiles[i])),header=T,stringsAsFactors = F)
    
  #   print(inputfiles[i])
  #   print(dim(dat))
  #   print(length(unique(dat$Species_name_orig)))
  #   print(length(unique(dat$location_orig)))
  # }
    
    dat <- dat[,!colnames(dat)%in%c("location_orig")]
    
    # remove white space #######################################
    dat$taxon_orig <- gsub("  "," ",dat$taxon_orig)
    dat$taxon_orig <- gsub("^\\s+|\\s+$", "",dat$taxon_orig) # trim leading and trailing whitespace
    dat$taxon_orig <- gsub("[$\xc2\xa0]", " ",dat$taxon_orig) # replace weird white space with recognised white space
    dat$taxon_orig <- gsub("  "," ",dat$taxon_orig)
    dat$taxon_orig <- gsub("\n"," ",dat$taxon_orig)
    
    dat <- dat[!is.na(dat$taxon_orig),]
    dat <- dat[dat$taxon_orig!="",]
    
    # loop over provided list of keywords to identify sub-species level information
    # subspIdent <- read.xlsx("Config/SubspecIdentifier.xlsx",colNames=F)[,1]
    # subspIdent <- gsub("\\.","",subspIdent)
    # subspIdent <- c(subspIdent,paste0(subspIdent,"\\."))
    # subspIdent <- paste0(paste("",subspIdent,""),".*$")
    # for (j in 1:length(subspIdent)){
    #   ind <- grep(subspIdent[j],dat$Species_name)
    #   dat$Species_name <- gsub(subspIdent[j],"",dat$Species_name)
    # }
    
    #### check griis names using 'rgibf' GBIF taxonomy ###########
    ## can be commented out to run without standardisation
    
    cat(paste0("\n    Working on ",FileInfo[i,"Dataset_brief_name"],"... \n"))
    dat <- CheckGBIFTax(dat)
    

    ## output #####################################################
    
    DB <- dat[[1]]
    mismatches <- dat[[2]]
    
    ## export full species list with original species names and names assigned by GBIF for checking
    fullspeclist <- rbind(fullspeclist,unique(DB[,c("taxon_orig","taxon","scientificName","GBIFstatus","GBIFstatus_Synonym","GBIFmatchtype","GBIFtaxonRank","GBIFusageKey","GBIFnote","species","genus","family","order","class","phylum","kingdom")]))
    
    DB <- unique(DB) # remove duplicates
    DB$GBIFstatus[is.na(DB$GBIFstatus)] <- "NoMatch"
    DB <- DB[,!colnames(DB)%in%c("GBIFstatus","GBIFmatchtype","GBIFtaxonRank","GBIFusageKey","GBIFnote","GBIFstatus_Synonym","species","genus","family","class","order","phylum","kingdom")]
    
    write.table(DB,file.path(workingDirectory,"Output","Intermediate",paste0("Step4_StandardTaxonNames_",FileInfo[i,"Dataset_brief_name"],".csv")),row.names=F)
    
    oo <- order(mismatches$taxon)
    mismatches <- unique(mismatches[oo,])
    
    write.table(mismatches,file.path(workingDirectory,"Output","Check",paste0("Missing_Taxa_",FileInfo[i,"Dataset_brief_name"],".csv")),row.names=F,col.names=F)
  }
  
  oo <- order(fullspeclist$kingdom,fullspeclist$phylum,fullspeclist$class,fullspeclist$order,fullspeclist$taxon)
  fullspeclist <- unique(fullspeclist[oo,])
  
  ## assign taxon ID unique to individual taxa #############
  ## identify unique taxa (obtained from GBIF)
  fullspeclist$sequence <- 1:nrow(fullspeclist)
  uni_taxa <- unique(fullspeclist$scientificName)
  uni_taxa <- data.frame(scientificName=uni_taxa[!is.na(uni_taxa)],stringsAsFactors=F)
  uni_taxa$taxonID <- 1:nrow(uni_taxa)

  ## merge taxonID with full taxa list
  fullspeclist_2 <- merge(fullspeclist,uni_taxa,by="scientificName",all=T)
  fullspeclist_2$taxonID[is.na(fullspeclist_2$taxonID)] <- 1:length(which(is.na(fullspeclist_2$taxonID))) +  max(fullspeclist_2$taxonID,na.rm=T)
  
  fullspeclist_2 <- fullspeclist_2[order(fullspeclist_2$sequence),]
  fullspeclist_2 <- fullspeclist_2[,-which(colnames(fullspeclist_2)=="sequence")]
  
  write.table(fullspeclist_2,file.path(workingDirectory,"Output","FullTaxaList",paste0(outputfilename,"_",version,"_","FullTaxaList.csv")),row.names=F)
              
  
  ## add taxon ID to data sets ##########
  
  taxon_id <- unique(fullspeclist_2[,c("taxonID","taxon_orig")])
  for (i in 1:length(inputfiles)){ # loop over inputfiles 
    dat <- read.table(file.path(workingDirectory,"Output","Intermediate",paste0("Step4_StandardTaxonNames_",FileInfo[i,"Dataset_brief_name"],".csv")),header=T,stringsAsFactors = F)
    dat <- merge(dat,taxon_id,by="taxon_orig",all.x=T)
    
    write.table(dat,file.path(workingDirectory,"Output","Intermediate",paste0("Step4_StandardTaxonNames_",FileInfo[i,"Dataset_brief_name"],".csv")),row.names=F)
  }  
}

# Standardise first record dates


GeteventDate <- function(FileInfo=NULL){
 
  ## identify input datasets based on file name "StandardSpec_....csv"
  allfiles <- list.files(file.path(workingDirectory,"Output","Intermediate"))
  inputfiles_all <- allfiles[grep("Step4_StandardTaxonNames_",allfiles)]
  inputfiles <- vector()
  for (i in 1:nrow(FileInfo)){
    # inputfiles <- c(inputfiles,grep(FileInfo[i,"Dataset_brief_name"],inputfiles_all,value=T))
    inputfiles <- c(inputfiles,paste("Step4_StandardTaxonNames_",FileInfo[i,"Dataset_brief_name"],".csv",sep=""))
  }
  inputfiles <- inputfiles[!is.na(inputfiles)]
  
  replacements <- read.xlsx(file.path(config_dir,"Guidelines_eventDates.xlsx"))
  replacements$Replacement[is.na(replacements$Replacement)] <- ""
  
  ## loop over databases ##########
  
  translated_eventDates <- list()
  flag_eventDate2_exists <- F
  
  for (i in 1:length(inputfiles)){
    
    dat <- read.table(file.path(workingDirectory,"Output","Intermediate",paste0(inputfiles[i])),header=T,stringsAsFactors = F)

    dat$eventDate_orig  <- dat$eventDate # keep original entry
    dat$eventDate2_orig <- dat$eventDate2 # keep original entry
    
    ## treat first records #############
    nonnumeric <- vector()
    if (any(colnames(dat)=="eventDate")){ 
    
      for (j in 1:nrow(replacements)){
        dat$eventDate[dat$eventDate==replacements$Entry[j]] <- replacements$Replacement[j]
      }
      dat$eventDate <- gsub("^\\s+|\\s+$", "",dat$eventDate) # trim leading and trailing whitespace
      
      ## test if all first records can be transferred to numeric
      firstrec_test <- dat$eventDate
      firstrec_test <- firstrec_test[!is.na(firstrec_test)]
      suppressWarnings( first2 <- as.numeric(firstrec_test)) # default warning is confusing; print meaningful warning below instead
      if (any(is.na(first2))){
        nonnumeric <- unique(firstrec_test[is.na(first2)]) # collect non-numeric entries
      } 
      
      ## convert first records to numeric
      suppressWarnings( dat$eventDate <- as.numeric(dat$eventDate))
    
      ## treat second first record if available #############
      if (any(colnames(dat)=="eventDate2")){
  
        for (j in 1:nrow(replacements)){
          # dat$eventDate2 <- gsub(replacements$Entry[j],replacements$Replacement[j],dat$eventDate2)
          dat$eventDate2[dat$eventDate2==replacements$Entry[j]] <- replacements$Replacement[j]
        }
        dat$eventDate2 <- gsub("^\\s+|\\s+$", "",dat$eventDate2) # trim leading and trailing whitespace
        
        ## test if all first records can be transferred to numeric
        firstrec_test <- dat$eventDate2
        firstrec_test <- firstrec_test[!is.na(firstrec_test)]
        suppressWarnings( first2 <- as.numeric(firstrec_test))
        if (any(is.na(first2))){
          nonnumeric <- c(nonnumeric,unique(firstrec_test[is.na(first2)])) # collect non-numeric entries
        } 
    
        ## convert first records to numeric
        suppressWarnings( dat$eventDate2 <- as.numeric(dat$eventDate2))
        
        ## calculate unique first record if two are provided
        ## if range between two first records > 1, take mean of both first records; otherwise, take the earliest (keep the one provided in 'eventDate')
        diff_records <- which((dat$eventDate2 - dat$eventDate)>0) # difference to check
        dat$eventDate[diff_records] <- round(rowMeans(dat[diff_records,c("eventDate","eventDate2")]))
      } 
      
      ## prepare output #####
      if (any(colnames(dat)=="eventDate2")){
        out_translated <- unique(dat[dat$eventDate!=dat$eventDate_orig | dat$eventDate2!=dat$eventDate_orig,c("eventDate","eventDate2","eventDate_orig","eventDate2_orig")])
        if (nrow(out_translated)>0){  # avoid situation of adding empty data sets
          out_translated$note <- NA
          ind <- (out_translated$eventDate2 - out_translated$eventDate)<0
          out_translated[which(ind),]$note <- "eventDate2 lies before eventDate"
          out_translated$origDB  <- FileInfo[i,1]
          flag_eventDate2_exists <- T
        }
      } else {
        out_translated <- unique(dat[dat$eventDate!=dat$eventDate_orig,c("eventDate","eventDate_orig")])
        if (nrow(out_translated)>0){  # avoid situation of adding empty data sets
          out_translated$note <- NA
          out_translated$origDB  <- FileInfo[i,1]
          if (flag_eventDate2_exists) {
            out_translated$eventDate2      <- NA
            out_translated$eventDate2_orig <- NA
            out_translated <- out_translated[,c("eventDate","eventDate2","eventDate_orig","eventDate2_orig")]
          }
        }
      }
      if (nrow(out_translated)>0){
        translated_eventDates[[i]] <- out_translated
      }
    }    

    ## Output #######################################
    
    if (length(nonnumeric)>0){
      cat(paste("\n    Warning: First records in",FileInfo[i,1],"contain non-numeric symbols. Converted to missing values. \n"))
      write.table(nonnumeric,file.path(workingDirectory,"Output","Check",paste0("NonNumeric_eventDates_",FileInfo[i,"Dataset_brief_name"],".csv")),row.names=F,col.names=F)
    } 

    write.table(dat,file.path(workingDirectory,"Output","Intermediate",paste0("Step5_StandardIntroYear_",FileInfo[i,"Dataset_brief_name"],".csv")),row.names=F)
    
  }
  
  if (length(translated_eventDates)>0){
    all_translated <- unique(do.call("rbind",translated_eventDates))
    write.table(all_translated,file.path(workingDirectory,"Output","Translated_eventDates.csv"),row.names=F)
  }
}

## -----------------------------
## Main execution (standalone / BIAB)
## -----------------------------
# When this file is sourced/run directly, run the standardisation steps in order
# This reads `DatabaseInfo.xlsx` from `workingDirectory/Config` (produced by PrepareDatasets)
# and writes cleaned datasets into `workingDirectory/Output/Cleaned/` and registers them via BIAB.
if (interactive() || identical(Sys.getenv("RUN_STANDARDISE_MAIN"), "1")) {
  message("Running Standardise pipeline (Standardise.R) using workingDirectory: ", workingDirectory)

  dbinfo_path <- file.path(workingDirectory, "Config", "DatabaseInfo.xlsx")
  if (!file.exists(dbinfo_path)) {
    stop("DatabaseInfo.xlsx not found at ", dbinfo_path, ". Please run PrepareDatasets.R or place DatabaseInfo.xlsx in workingDirectory/Config.")
  }

  FileInfo <- openxlsx::read.xlsx(dbinfo_path, sheet = 1)
  if (nrow(FileInfo) == 0) stop("No entries in DatabaseInfo.xlsx; nothing to process.")

  # Ensure Output/Cleaned exists
  cleaned_dir <- file.path(workingDirectory, "Output", "Cleaned")
  if (!dir.exists(cleaned_dir)) dir.create(cleaned_dir, recursive = TRUE)

  # Run core steps
  StandardiseTerms(FileInfo)
  StandardiseLocationNames(FileInfo)
  StandardiseTaxonNames(FileInfo)
  GeteventDate(FileInfo)

  # For each dataset, copy the Step4 result as the final cleaned dataset and register it
  for (i in seq_len(nrow(FileInfo))) {
    ds <- FileInfo$Dataset_brief_name[i]
    step4 <- file.path(workingDirectory, "Output", "Intermediate", paste0("Step4_StandardTaxonNames_", ds, ".csv"))
    if (file.exists(step4)) {
      cleaned_path <- file.path(cleaned_dir, paste0(ds, "_cleaned.csv"))
      file.copy(step4, cleaned_path, overwrite = TRUE)
      message("Wrote cleaned dataset: ", cleaned_path)
      register_biab(paste0("cleaned_", ds), cleaned_path)
    } else {
      warning("Expected Step4 output not found for dataset: ", ds, " (", step4, ")")
    }

    # Also include standardized first-records (Step5) if produced
    step5 <- file.path(workingDirectory, "Output", "Intermediate", paste0("Step5_StandardIntroYear_", ds, ".csv"))
    if (file.exists(step5)) {
      cleaned_fr <- file.path(cleaned_dir, paste0(ds, "_cleaned_eventDates.csv"))
      file.copy(step5, cleaned_fr, overwrite = TRUE)
      message("Wrote cleaned event-date dataset: ", cleaned_fr)
      register_biab(paste0("cleaned_eventDates_", ds), cleaned_fr)
    }
  }

  message("Standardise pipeline finished. Cleaned outputs are in: ", cleaned_dir)
}
  
