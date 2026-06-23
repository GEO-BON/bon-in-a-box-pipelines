
####### SInAS workflow: Integration and standardisation of alien species data ###########
##
## Step 2c: Standardisation of species names using the GBIF backbone taxonomy
##
## Species names are standardised according to the GBIF backbone taxonomy. The protocol 
## to access GBIF and treat results is implemented in CheckGBIFTax.r.
## Script requires internet connection.
##
## Hanno Seebens, Giessen, 02.07.2025
#########################################################################################


StandardiseTaxonNames <- function(FileInfo=NULL){

  ## identify input datasets based on file name "StandardColumns_....csv"
  allfiles <- list.files(file.path("Output","Intermediate"))
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
    
    dat <- read.table(file.path("Output","Intermediate",paste0(inputfiles[i])),header=T,stringsAsFactors = F)
    
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
    
    write.table(DB,file.path("Output","Intermediate",paste0("Step4_StandardTaxonNames_",FileInfo[i,"Dataset_brief_name"],".csv")),row.names=F)
    
    oo <- order(mismatches$taxon)
    mismatches <- unique(mismatches[oo,])
    
    write.table(mismatches,file.path("Output","Check",paste0("Missing_Taxa_",FileInfo[i,"Dataset_brief_name"],".csv")),row.names=F,col.names=F)
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
  
  write.table(fullspeclist_2,file.path("Output","FullTaxaList",paste0(outputfilename,"_",version,"_","FullTaxaList.csv")),row.names=F)
              
  
  ## add taxon ID to data sets ##########
  
  taxon_id <- unique(fullspeclist_2[,c("taxonID","taxon_orig")])
  for (i in 1:length(inputfiles)){ # loop over inputfiles 
    dat <- read.table(file.path("Output","Intermediate",paste0("Step4_StandardTaxonNames_",FileInfo[i,"Dataset_brief_name"],".csv")),header=T,stringsAsFactors = F)
    dat <- merge(dat,taxon_id,by="taxon_orig",all.x=T)
    
    write.table(dat,file.path("Output","Intermediate",paste0("Step4_StandardTaxonNames_",FileInfo[i,"Dataset_brief_name"],".csv")),row.names=F)
  }  
}
