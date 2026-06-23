
############ SInAS workflow: Integration and standardisation of alien species data #####################
##
## Step 2d: Standardisation of event dates/first records
##
## Event dates are modified according to a set of rules defined in "Guidelines_eventDates.xlsx",
## then converted to numerics and - if necessary - merged to get single first records.
##
## Hanno Seebens, Gießen, 02.07.2025
#########################################################################################################


GeteventDate <- function(FileInfo=NULL){
 
  ## identify input datasets based on file name "StandardSpec_....csv"
  allfiles <- list.files(file.path("Output","Intermediate"))
  inputfiles_all <- allfiles[grep("Step4_StandardTaxonNames_",allfiles)]
  inputfiles <- vector()
  for (i in 1:nrow(FileInfo)){
    # inputfiles <- c(inputfiles,grep(FileInfo[i,"Dataset_brief_name"],inputfiles_all,value=T))
    inputfiles <- c(inputfiles,paste("Step4_StandardTaxonNames_",FileInfo[i,"Dataset_brief_name"],".csv",sep=""))
  }
  inputfiles <- inputfiles[!is.na(inputfiles)]
  
  replacements <- read.xlsx(file.path("Config","Guidelines_eventDates.xlsx"))
  replacements$Replacement[is.na(replacements$Replacement)] <- ""
  
  ## loop over databases ##########
  
  translated_eventDates <- list()
  flag_eventDate2_exists <- F
  
  for (i in 1:length(inputfiles)){
    
    dat <- read.table(file.path("Output","Intermediate",paste0(inputfiles[i])),header=T,stringsAsFactors = F)

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
      write.table(nonnumeric,file.path("Output","Check",paste0("NonNumeric_eventDates_",FileInfo[i,"Dataset_brief_name"],".csv")),row.names=F,col.names=F)
    } 

    write.table(dat,file.path("Output","Intermediate",paste0("Step5_StandardIntroYear_",FileInfo[i,"Dataset_brief_name"],".csv")),row.names=F)
    
  }
  
  if (length(translated_eventDates)>0){
    all_translated <- unique(do.call("rbind",translated_eventDates))
    write.table(all_translated,file.path("Output","Translated_eventDates.csv"),row.names=F)
  }
}
  