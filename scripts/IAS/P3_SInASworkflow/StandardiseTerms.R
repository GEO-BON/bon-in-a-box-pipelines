
####### SInAS workflow: Integration and standardisation of alien species data ###########
##
## Step 2a: Standardisation of terminologies using a set of translation tables 
##
## Manuela Gómez-Suárez, Hanno Seebens, Giessen, 02.07.2025
#########################################################################################


StandardiseTerms <- function(FileInfo=NULL){
  
  ## identify input datasets based on file name "StandardSpec_....csv"
  allfiles <- list.files(file.path("Output","Intermediate"))
  inputfiles_all <- allfiles[grep("Step1_StandardColumns_",allfiles)]
  inputfiles <- vector()
  for (i in 1:nrow(FileInfo)){
    # inputfiles <- c(inputfiles,grep(FileInfo[i,"Dataset_brief_name"],inputfiles_all,value=T))
    inputfiles <- c(inputfiles,paste("Step1_StandardColumns_",FileInfo[i,"Dataset_brief_name"],".csv",sep=""))
  }
  inputfiles <- inputfiles[!is.na(inputfiles)]
  
  ## translation tables
  translation_estabmeans <- read.xlsx(file.path("Config","Translation_establishmentMeans.xlsx"),sheet=1)
  translation_occurrence <- read.xlsx(file.path("Config","Translation_occurrenceStatus.xlsx"),sheet=1)
  translation_degrEstab <- read.xlsx(file.path("Config","Translation_degreeOfEstablishment.xlsx"),sheet=1)
  translation_pathway <- read.xlsx(file.path("Config","Translation_pathway.xlsx"),sheet=1)
  translation_habitat <- read.xlsx(file.path("Config","Translation_habitat.xlsx"),sheet=1)
  
  for (i in 1:length(inputfiles)){#
    
    dat <- read.table(file.path("Output","Intermediate",inputfiles[i]),header=T,stringsAsFactors = F)
    
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
      write.table(all_unresolved,file.path("Output","Check",paste0("Unresolved_Terms_",FileInfo[i,"Dataset_brief_name"],".csv")),row.names=F,col.names=F)
      cat(paste0("\n    Warning: Unresolved terms in ",FileInfo[i,"Dataset_brief_name"],". Check file UnresolvedTerms_* in subfolder Check/ \n"))
    }
    
    write.table(dat,file.path("Output","Intermediate",paste0("Step2_StandardTerms_",FileInfo[i,"Dataset_brief_name"],".csv")),row.names=F)
    
  }
}
