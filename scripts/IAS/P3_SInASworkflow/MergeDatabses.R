
####### SInAS workflow: Integration and standardisation of alien species data ###########
##
## Step 3: Merging of standardised databases of alien species data
##
## Manuela Gómez-Suárez, Hanno Seebens, Giessen, 17.06.2025
#########################################################################################


MergeDatabases <- function(FileInfo=NULL, 
                           version=NULL,
                           outputfilename=NULL,
                           output=NULL){
  
  ## identify input datasets based on file name "StandardSpec_....csv"
  allfiles <- list.files(file.path("Output","Intermediate"))
  inputfiles_all <- allfiles[grep("Step5_StandardIntroYear_",allfiles)]
  inputfiles <- vector()
  for (i in 1:nrow(FileInfo)){
    # inputfiles <- c(inputfiles,grep(FileInfo[i,"Dataset_brief_name"],inputfiles_all,value=T))
    inputfiles <- c(inputfiles,paste("Step5_StandardIntroYear_",FileInfo[i,"Dataset_brief_name"],".csv",sep=""))
  }
  inputfiles <- inputfiles[!is.na(inputfiles)]
  
  # specify dedicated databases on alien species to fill out establishmentMeans when this information is not already given by the database 
  alienDB <- c("FirstRecords", "GAVIA", "MacroFungi", "GRIIS", "DAMA", "AmphRep") # Databases only including data on alien species
  
  ## merge columns #######################################
  
  for (i in 1:length(inputfiles)){#
    
    dat <- read.table(file.path("Output","Intermediate",paste0(inputfiles[i])),header=T,stringsAsFactors = F)

    cnames <- colnames(dat)
    cnames <- cnames[!cnames%in%c("taxon_orig","location_orig","Kingdom_user","Country_ISO","ISO3","eventDate_orig","Taxon_group")]
    dat <- dat[,colnames(dat)%in%cnames]

    dat$origDB <- FileInfo[i,1]
    
    # remove records whose location could not be standardized 
    dat <- dat[!is.na(dat$locationID), ]
    
    # update establishmentMeans for entries without information based on source
    # Check for presence of any `establishmentMeans`-related columns
    if (any(grepl("^establishmentMeans", cnames))) {
      # Update existing `establishmentMeans` columns
      est_means_cols <- grep("^establishmentMeans", cnames, value = TRUE)
      for (col in est_means_cols) {
        dat[[col]] <- ifelse(dat[[col]] == "" & str_detect(dat$origDB, paste(alienDB, collapse = "|")), 
                             "introduced", dat[[col]])
      }
    } else {
      # Create a new `establishmentMeans` column if none exist and fill after the dedicated databases for alien distributions
      dat$establishmentMeans <- ifelse(str_detect(dat$origDB, paste(alienDB, collapse = "|")), 
                                       "introduced", "")
    }
    
    # eval(parse(text=paste0("dat$",substitute(a,list(a=FileInfo[i,1])),"<-\"x\""))) # add column with database information

    if (i == 1) {
      alldat <- dat
    } else {
      
      # Check for and resolve duplicate columns
      if ("taxonID.x" %in% colnames(dat) && "taxonID.y" %in% colnames(dat)) {
        # Confirm the columns are identical
        if (all(dat$taxonID.x == dat$taxonID.y, na.rm = TRUE)) {
          dat$taxonID <- dat$taxonID.x  # consolidate columns
          dat <- dat[, !colnames(dat) %in% c("taxonID.x", "taxonID.y")]  # Drop now redundant columns
        } else {
          stop("The columns 'taxonID.x' and 'taxonID.y' are not identical.")
        }
      }
      
      # Merge the databases
      
      # Create empty establishmentMeans column if there is none present in "dat"
      if (!"establishmentMeans" %in% colnames(dat)) {
        dat$establishmentMeans <- NA  # Create an empty column
      }
      # Create empty establishmentMeans column if there is none present inn 'alldat'
      if (!"establishmentMeans" %in% colnames(alldat)) {
        alldat$establishmentMeans <- NA
      }

      alldat <- merge(alldat, dat, by = c("location", "locationID", "taxon", "scientificName", "taxonID","establishmentMeans"), all = TRUE)

      alldat <- alldat %>%
        mutate(across(starts_with("eventDate"), as.character))
      
      # clean records flagged as both: introduced and uncertain
      alldat <- alldat %>%
        group_by(location, locationID, taxon, scientificName, taxonID) %>%
        mutate(establishmentMeans = ifelse(all(c("introduced", "uncertain") %in% establishmentMeans),
          "introduced; uncertain",
          establishmentMeans)) |> 
        ungroup()
      
      # merge records flagged as both: introduced and uncertain
      alldat <- alldat |>
        mutate(.by = c(location, locationID, taxon, scientificName, taxonID),
               g = (establishmentMeans %in% c("introduced", "uncertain") &
                      all(c("introduced", "uncertain") %in% establishmentMeans))) |>
        reframe(.by = c(location, locationID, taxon, scientificName, taxonID, g),
                across(everything(), ~ if (first(g)) paste(.x, collapse = "; ") else .x)) |>
        dplyr::select(-g)
 
      # clean records flagged as both: introduced and uncertain
      alldat <- alldat %>%
        group_by(location, locationID, taxon, scientificName, taxonID) %>%
        mutate(establishmentMeans = ifelse(all(c("introduced", "uncertain") %in% establishmentMeans),
                                           "introduced; uncertain",
                                           establishmentMeans)) |> 
        ungroup()
      
      
      ## treat duplicated columns (named by R default ".x" and ".y")
      if (any(grepl("\\.y",colnames(alldat)))){
        if (any(colnames(alldat)=="eventDate.x")){ # solve multiple first records
          ## select the minimum of multiple first records
          alldat$eventDate <- apply(alldat[,c("eventDate.x","eventDate.y")],1,function(s) ifelse(all(is.na(s)),NA,min(s,na.rm=T)))
          alldat <- alldat[,!colnames(alldat)%in%c("eventDate.x","eventDate.y")]
        }
        
        while(any(grepl("\\.y",colnames(alldat)))){ # check if discrepancy still exists
          colname_dupl <- colnames(alldat)[grep("\\.y",colnames(alldat))][1] # identify duplicated column
          colname_dupl <- gsub("\\..+$","",colname_dupl) # create new column new
          colnames_dupl <- colnames(alldat)[grep(colname_dupl,colnames(alldat))] # identify .x and .y component
          ## merge both columns into a new one by combining the content separated by ';'
          eval(parse(text=paste0("alldat$",substitute(a,list(a=colname_dupl)),"<-paste(alldat$",substitute(a,
                        list(a=colname_dupl)),".x,alldat$",substitute(a,list(a=colname_dupl)),".y,sep=\"; \")"))) # add column with database information
          alldat <- alldat[,!colnames(alldat)%in%colnames_dupl] # remove .x and .y columns
        }
      }
    }
  }

  #### merge rows ############################
  
  ## merge remaining content of rows defined by the "by" statement
  dt <- as.data.table(alldat)
  dt$eventDate <- as.character(dt$eventDate)
  alldat <- dt[,lapply(.SD,function(s) paste(s,collapse="; ")),by=list(taxon,location,locationID,taxonID,scientificName,establishmentMeans)]


   # dt[,establishmentMeans:=gsub("; NA","",establishmentMeans)]
   # dt[,establishmentMeans:=unlist(lapply(strsplit(alldat[,colname_dupl],"; "),function(s) paste(unique(s),collapse="; ")))]
  
  
  ## standardise column entries
  alldat <- as.data.frame(alldat,stringsAsFactors=F)  
  alldat$eventDate <- as.character(alldat$eventDate)
  
  
  # clean strings
  ind_col <- which(!colnames(alldat)%in%c("taxon","taxonID","location","locationID","scientificName","establishmentMeans"))

  for (i in ind_col){
    alldat[,i] <- unlist(lapply(strsplit(alldat[,i],"; "),function(s) paste(sort(unique(s)),collapse="; ")))
    alldat[,i] <- gsub("; NA","",alldat[,i]) # clean new column
    alldat[,i] <- gsub("NA; ","",alldat[,i]) # clean new column
    alldat[,i] <- gsub("^; ","",alldat[,i]) # clean new column
    alldat[,i] <- gsub("; $","",alldat[,i]) # clean new column
    alldat[,i] <- gsub(";$","",alldat[,i]) # clean new column
    alldat[,i] <- gsub(" ; "," ",alldat[,i]) # clean new column
    alldat[,i] <- gsub("^NA$","",alldat[,i]) # clean new column
  }

  #unlist(lapply(strsplit(as.character(output[,9]),"; "),function(s) paste(sort(unique(s)),collapse="; ")))

  ## remove duplicated entries
  ind_dupl <- duplicated(alldat) # remove identical lines
  alldat <- alldat[!ind_dupl,]
  
  # specify columns to check for duplicates 
  ind_dupl <- duplicated(alldat[,c("taxon","location","establishmentMeans")]) # remove duplicated species-region combinations
  all_dat_dupl <- unique(alldat[ind_dupl,c("taxon","location","establishmentMeans")]) # remove duplicated species-region combinations

  
  # ind_dupl <- duplicated(alldat[,c("taxon","location")]) # remove duplicated species-region combinations
  # all_dat_dupl <- unique(alldat[ind_dupl,c("taxon","location")])
  ind_rm <- col_dupl <- vector()
  for (j in 1:nrow(all_dat_dupl)){
    
    ind_each <- which(alldat$taxon == all_dat_dupl$taxon[j] & alldat$location == all_dat_dupl$location[j])

    
    for (k in 1:dim(alldat)[2]){ # loop over columns
      if (colnames(alldat)[k]%in%c("location", "stateProvince","locationID","taxon","scientificName","taxonID","establishmentMeans")) next # ignore these columns
      if (all(is.na(alldat[ind_each,k]))) next # skip if all NA
      if (all(duplicated(alldat[ind_each,k])[-1])){ # skip if all equal (non-NA)
        next 
      } else {
        ind_NA <- is.na(alldat[ind_each,k]) # avoid NAs
        if (length(unique(alldat[ind_each,k][!ind_NA]))==1){ # if only a single value is non-NA, add non-NA information to first row
          alldat[ind_each,k][1] <- alldat[ind_each,k][!ind_NA][1]
        } else { # if deviating entries exit, merge content into first row
          if (colnames(alldat)[k]=="eventDate"){ # treat first records differently
            alldat[ind_each,k][1] <- min(alldat[ind_each,k],na.rm = T) # select earliest first record
          } else {
            entries <- unique(alldat[ind_each,k][!ind_NA])
            entries <- entries[entries!=""]
            alldat[ind_each,k][1] <- paste(entries,collapse="; ") # concatenate unequal row entries
            col_dupl <- c(col_dupl,colnames(alldat)[k]) # store column with deviating information for report
          }
        }
        ind_rm <- c(ind_rm,ind_each[-1]) # collect rows to remove (all except the first one)
      }
    }
  }
  if (length(ind_rm)>0) alldat <- alldat[-unique(ind_rm),] # remove all duplicates
  if (length(col_dupl)>0) cat(paste0("\n    Note: Multiple entries for the same record. Check column '",unique(col_dupl),"' in final data set for entries separated by ';'. \n"))

  ## select minimum first record
  ind_dupl_fr <- grep("; ",alldat$eventDate)
  single_fr <- lapply(strsplit(alldat$eventDate[ind_dupl_fr],"; "),function(s) min(as.integer(s)))
  alldat$eventDate[ind_dupl_fr] <- unlist(single_fr)
  
  # fill habitat column
  alldat <- alldat %>%
    group_by(taxonID) %>%
    mutate(
      habitat = habitat[which.max(nchar(habitat, keepNA = FALSE))])
  
  ## output #############################################

  ## sort by taxonomic tree
  fulltaxalist <- read.table(file.path("Output","FullTaxaList",paste0(outputfilename,"_",version,"_","FullTaxaList.csv")),stringsAsFactors = F,header=T)
  fulltaxalist <- unique(fulltaxalist[,c("taxonID","kingdom","phylum","class","order","family")])
  alldat <- merge(alldat,fulltaxalist,by="taxonID",all.x=T)
  
  oo <- order(alldat$location,alldat$kingdom,alldat$phylum,alldat$class,alldat$order,alldat$family,alldat$scientificName)

  alldat <- alldat[oo,]
  
  ## identify columns for output
  all_addit_cols <- paste(FileInfo$Column_additional,collapse="; ")
  all_addit_cols <- unlist(strsplit(all_addit_cols,"; "))
  all_addit_cols <- all_addit_cols[all_addit_cols!="NA"]
  
  # identify columns for output depending on desired spatial aggregation
  key_columns <- c("location", "locationID", "taxon", "scientificName", "taxonID", "eventDate", 
                     "habitat", "occurrenceStatus", "establishmentMeans", "degreeOfEstablishment", 
                     "pathway", "origDB", "bibliographicCitation")

  
  columns_out <- colnames(alldat)[colnames(alldat) %in% c(key_columns, all_addit_cols)]
  ind <- match(key_columns, columns_out)
  # Reorder columns: prioritize key columns, then additional columns
  columns_out <- unique(c(columns_out[ind[which(!is.na(ind))]], columns_out[which(is.na(ind))], all_addit_cols))
  columns_out <- columns_out[!is.na(columns_out)]
  
  
  # if (any(colnames(alldat)=="eventDate")){
  #   columns_out <- c("location","taxon","scientificName","eventDate","origDB","bibliographicCitation",all_addit_cols)
  # } else {
  #   columns_out <- c("location","taxon","scientificName","origDB","bibliographicCitation",all_addit_cols)
  # }

  alldat_out <- alldat[,columns_out]
  alldat_out[is.na(alldat_out)] <- ""
  alldat_out[alldat_out=="NA"] <- ""
  
  # set final names for the columns
  colnames(alldat_out)[colnames(alldat_out) == "FirstRecord_orig"] <- "eventDate_orig"

  # write main output of workflow
  setDT(alldat_out) # Convert output to a data.table if it isn’t already
  
  # Clean the establishmentMeans and occurrenceStatus columns
  # alldat_out[, establishmentMeans := 
  #          sapply(establishmentMeans, function(x) {
  #            paste(unique(unlist(strsplit(x, "; "))), collapse = "; ")
  #          })]
  # alldat_out[, occurrenceStatus := 
  #              sapply(occurrenceStatus, function(x) {
  #                paste(unique(unlist(strsplit(x, "; "))), collapse = "; ")
  #              })]
  
  # Remove additional characters "\" from the reference column
  alldat_out$bibliographicCitation <- gsub('["\']', '', alldat_out$bibliographicCitation)

  
  
  write.table(alldat_out,file.path("Output","Merged",paste(outputfilename,"_",version,".csv",sep="")),row.names=F)
  
  # dat <- read.table(paste("Output/",outputfilename,version,".csv",sep=""),stringsAsFactors = F,header=T)
  # dat <- dat[dat$GBIFstatus!="Missing",]
  
  ## ending line
  cat(paste("\n Successfully established version",version,"of",outputfilename,"file. \n"))
  
  ## delete intermediate results if selected ########
  if (!output) {
    interm_res <- list.files(file.path("Output","Intermediate"))
    interm_res <- interm_res[grep("Standard",interm_res)]
    file.remove(paste0("Output",interm_res))
  }
}
