## ------------------------------------------------------
## Script name: Step 2c: Standardisation of taxon names of SInAS workflow
##
## Purpose of script: Checks and replaces species names using 'rgibf' GBIF taxonomy. 
## This script was originally developed by Seebans et al 2025 (see https://zenodo.org/records/15799412). It has been updated to run in parallel using mcpbapply functions. 
##
## Author: Saxbee Affleck
##
## Date Created: 2025-08-27
## ------------------------------------------------------
## ------------------------------------------------------

CheckGBIFTax <- function(taxon_names=NULL,
                         column_name_taxa=NULL){
  
  ## check input variable
  if (is.null(taxon_names)){
    
    stop("No taxon names provided.")
    
  } else if (is.character(taxon_names)){ # check if input file is a vector
    
    dat <- as.data.frame(taxon_names)
    colnames(dat) <- "taxon_orig"
    
  } else if (is.data.frame(taxon_names)){ # check if input file is a data.frame
    
    dat <- taxon_names
    
  } else {
    
    stop("Cannot coerce data into data.frame. Please provide a data.frame or vector as input.")
    
  }
  
  if (!is.null(column_name_taxa)){ # check if column name of taxa provided
    
    colnames(dat)[colnames(dat)==column_name_taxa] <- "taxon_orig" # rename to standard column name
    
  }
  if (all(colnames(dat)!="taxon_orig")){ # check if column "taxon_orig" can be found
    
    stop("No column with taxon names found. Please specify in column_name_taxa.")
    
  }
  
  MatchNames <- pbmcapply::pbmclapply(1:nrow(dat), function(x) {
    tryCatch(
      {
        
        Row <- dat[x,]
        
        Row$scientificName <- NA
        Row$taxon <- Row$taxon_orig
        Row$GBIFstatus <- "MISSING"
        Row$GBIFmatchtype <- NA
        Row$GBIFnote <- NA
        Row$GBIFstatus_Synonym <- NA
        Row$species <- NA
        Row$genus <- NA
        Row$family <- NA
        Row$class <- NA
        Row$order <- NA
        Row$phylum <- NA
        Row$kingdom <- NA 
        Row$GBIFtaxonRank <- NA
        Row$GBIFusageKey <- NA
        
        if (any(colnames(Row)=="kingdom_user")){
          taxlist_lifeform <- unique(Row[,c("taxon","kingdom_user")])
          taxlist <- taxlist_lifeform$taxon
        } else if (any(colnames(Row)=="Author")){
          taxlist <- unique(paste(Row$taxon,Row$Author))
        } else {
          taxlist <- unique(Row$taxon)
        }
        n_taxa <- length(taxlist)
        
        # #setup progress bar
        # pb <- txtProgressBar(min=0, max=n_taxa, initial=0,style = 3)
        
        options(warn=-1) # the use of 'tibbles' data frame generates warnings as a bug; if solved this options() should be turned off
        
        mismatches <- data.frame(taxon=NA,status=NA,matchType=NA)
        for (j in 1:n_taxa){# loop over all species names; takes some hours...
          
          # select species name and download taxonomy
          ind_tax <- which(Row$taxon==taxlist[j])
          db_all <- name_backbone_verbose(taxlist[j],strict=T) # check for names and synonyms
          db <- db_all[["data"]]
          alternatives <- db_all$alternatives
          
          if (any(db$status=="ACCEPTED" & db$matchType=="EXACT" & colnames(db)=="canonicalName")){ 
            
            ### EXACT MATCHES: select only accepted names and exact matches ##############################################
            
            Row$taxon[ind_tax]      <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$canonicalName[1]
            Row$scientificName[ind_tax] <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$scientificName[1]
            Row$GBIFstatus[ind_tax]      <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$status[1]
            Row$GBIFmatchtype[ind_tax]   <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$matchType[1]
            Row$GBIFtaxonRank[ind_tax]        <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$rank[1]
            Row$GBIFusageKey[ind_tax]        <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$usageKey[1]
            
            try(Row$species[ind_tax]     <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$species[1],silent=T)
            try(Row$genus[ind_tax]       <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$genus[1],silent=T)
            try(Row$family[ind_tax]      <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$family[1],silent=T)
            try(Row$class[ind_tax]       <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$class[1],silent=T)
            try(Row$order[ind_tax]       <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$order[1],silent=T)
            try(Row$phylum[ind_tax]      <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$phylum[1],silent=T)
            try(Row$kingdom[ind_tax]     <- db[db$status=="ACCEPTED" & db$matchType=="EXACT",]$kingdom[1],silent=T)
            
            next # jump to next taxon
            
          } else if (any(db$status=="SYNONYM" & db$matchType=="EXACT" & colnames(db)=="species")) { # select synonyms
            
            ## SYNONYMS #################################################################################
            
            ## flag that it is a synonym
            Row$GBIFstatus[ind_tax] <- db[db$status=="SYNONYM" & db$matchType=="EXACT",]$status[1]
            Row$GBIFmatchtype[ind_tax] <- db[db$status=="SYNONYM" & db$matchType=="EXACT",]$matchType[1]
            Row$GBIFtaxonRank[ind_tax]     <- db[db$status=="SYNONYM" & db$matchType=="EXACT",]$rank[1]
            Row$GBIFusageKey[ind_tax]     <- db[db$status=="SYNONYM" & db$matchType=="EXACT",]$usageKey[1]
            
            ## check if accepted name is provided in 'alternatives'
            if (any(alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT")){
              
              if (nrow(alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",])>1) {
                Row$GBIFnote[ind_tax] <- "No single accepted name in GBIF"  # !!! new string
              } 
              
              Row$scientificName[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$scientificName[1]
              Row$taxon[ind_tax]          <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$canonicalName[1]
              
              try(Row$species[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$species[1],silent=T)
              try(Row$genus[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$genus[1],silent=T)
              try(Row$family[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$family[1],silent=T)
              try(Row$class[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$class[1],silent=T)
              try(Row$order[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$order[1],silent=T)
              try(Row$phylum[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$phylum[1],silent=T)
              try(Row$kingdom[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$kingdom[1],silent=T)
              
              next # jump to next taxon
              
            } else if (db$rank=="SPECIES"){  ## try to get author name of synonym (not provided in 'db')(works only for species)
              
              Row$taxon[ind_tax]    <- db[db$status=="SYNONYM" & db$matchType=="EXACT",]$species[1]
              Row$GBIFstatus[ind_tax]    <- db[db$status=="SYNONYM" & db$matchType=="EXACT",]$status[1]
              Row$GBIFmatchtype[ind_tax] <- db[db$status=="SYNONYM" & db$matchType=="EXACT",]$matchType[1]
              Row$GBIFtaxonRank[ind_tax]      <- db[db$status=="SYNONYM" & db$matchType=="EXACT",]$rank[1]
              Row$GBIFusageKey[ind_tax]      <- db[db$status=="SYNONYM" & db$matchType=="EXACT",]$usageKey[1]
              
              db_all_2 <- name_backbone_verbose(Row$taxon[ind_tax][1],strict=T) # get scientific name
              db_2 <- db_all_2[["data"]]
              
              if (db_2$matchType=="EXACT"){ # exact matches
                Row$scientificName[ind_tax]  <- db_2[db_2$matchType=="EXACT",]$scientificName[1]
                Row$GBIFstatus_Synonym[ind_tax]<- db_2[db_2$matchType=="EXACT",]$status[1]
                try(Row$species[ind_tax]     <- db_2[db_2$matchType=="EXACT",]$species[1],silent=T)
                try(Row$genus[ind_tax]       <- db_2[db_2$matchType=="EXACT",]$genus[1],silent=T)
                try(Row$family[ind_tax]      <- db_2[db_2$matchType=="EXACT",]$family[1],silent=T)
                try(Row$class[ind_tax]       <- db_2[db_2$matchType=="EXACT",]$class[1],silent=T)
                try(Row$order[ind_tax]       <- db_2[db_2$matchType=="EXACT",]$order[1],silent=T)
                try(Row$phylum[ind_tax]      <- db_2[db_2$matchType=="EXACT",]$phylum[1],silent=T)
                try(Row$kingdom[ind_tax]     <- db_2[db_2$matchType=="EXACT",]$kingdom[1],silent=T)
              }
            }
            next
            
          } else if (any(db$status=="ACCEPTED" & db$matchType=="FUZZY" & db$confidence==100 & colnames(db)=="canonicalName")) { 
            
            ## FUZZY MATCHES #################################################################################
            
            Row$taxon[ind_tax]      <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$canonicalName[1]
            Row$scientificName[ind_tax] <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$scientificName[1]
            Row$GBIFstatus[ind_tax]      <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$status[1]
            Row$GBIFmatchtype[ind_tax]   <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$matchType[1]
            Row$GBIFtaxonRank[ind_tax]        <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$rank[1]
            Row$GBIFusageKey[ind_tax]        <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$usageKey[1]
            
            Row$scientificName[ind_tax] <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$scientificName[1]
            try(Row$species[ind_tax] <-db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$species[1],silent=T)
            try(Row$genus[ind_tax]   <-  db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$genus[1],silent=T)
            try(Row$family[ind_tax]  <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$family[1],silent=T)
            try(Row$class[ind_tax]   <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$class[1],silent=T)
            try(Row$order[ind_tax]   <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$order[1],silent=T)
            try(Row$phylum[ind_tax]  <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$phylum[1],silent=T)
            try(Row$kingdom[ind_tax] <- db[db$status=="ACCEPTED" & db$matchType=="FUZZY",]$kingdom[1],silent=T)
            
            next # jump to next taxon
            
          } else if (any(alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT") & any(colnames(alternatives)=="species")){
            
            if (length(unique(alternatives$phylum))>1){ # check whether entry exists for different phyla; likely indicates a homonym
              
              ## case: multiple accepted names in "alternatives" from different phyla
              
              ## HOMONYMS #################################################################################
              ## check for alternative names because of e.g. multiple entries for different taxonomic groups in GBIF...
              
              Row$GBIFnote[ind_tax]        <- "Homonym in GBIF"
              
              ## check information of kingdom provided by user and selected respective author
              if (any(colnames(Row)=="kingdom_user")) {
                if (length(unique(alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$family))>1) print(paste(taxlist[j],"name occurrs in more than one family! To resolve this, you may provide information about author in original database, or kingdom or taxonomic group in DatabaseInfo.xlsx."))
                
                Row$taxon[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$species[1]
                
                Row$scientificName[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$scientificName[1]
                Row$GBIFstatus[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$status[1]
                Row$GBIFmatchtype[ind_tax]   <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$matchType[1]
                Row$GBIFtaxonRank[ind_tax]        <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$rank[1]
                Row$GBIFusageKey[ind_tax]        <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$usageKey[1]
                
                try(Row$species[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$species[1],silent=T)
                try(Row$genus[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$genus[1],silent=T)
                try(Row$family[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$family[1],silent=T)
                try(Row$class[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$class[1],silent=T)
                try(Row$order[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$order[1],silent=T)
                try(Row$phylum[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$phylum[1],silent=T)
                try(Row$kingdom[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom==taxlist_lifeform[j,2],]$kingdom[1],silent=T)
                
                next
              }
              
              ## select entries from cross-taxonomic databases from certain taxa
              if (any(colnames(Row)=="Taxon_group")) { # !!!!! new line
                if (unique(Row$Taxon_group)!="All"){ # check if 'Taxon_group' provides useful information
                  if (grepl("Vascular plants",unique(Row$Taxon_group))){ # case of vascular plants
                    
                    Row$taxon[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$species[1]
                    
                    Row$scientificName[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$scientificName[1]
                    Row$GBIFstatus[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$status[1]
                    Row$GBIFmatchtype[ind_tax]   <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$matchType[1]
                    Row$GBIFtaxonRank[ind_tax]        <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$rank[1]
                    Row$GBIFusageKey[ind_tax]        <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$usageKey[1]
                    
                    try(Row$species[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$species[1],silent=T)
                    try(Row$genus[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$genus[1],silent=T)
                    try(Row$family[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$family[1],silent=T)
                    try(Row$class[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$class[1],silent=T)
                    try(Row$order[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$order[1],silent=T)
                    try(Row$phylum[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$phylum[1],silent=T)
                    try(Row$kingdom[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$kingdom=="Plantae",]$kingdom[1],silent=T)
                  }
                  if (grepl("Reptiles",unique(Row$Taxon_group))){
                    
                    Row$taxon[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$species[1]
                    
                    Row$scientificName[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$scientificName[1]
                    Row$GBIFstatus[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$status[1]
                    Row$GBIFmatchtype[ind_tax]   <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$matchType[1]
                    Row$GBIFtaxonRank[ind_tax]            <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$rank[1]
                    Row$GBIFusageKey[ind_tax]            <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$usageKey[1]
                    
                    try(Row$species[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$species[1],silent=T)
                    try(Row$genus[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$genus[1],silent=T)
                    try(Row$family[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$family[1],silent=T)
                    try(Row$class[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$class[1],silent=T)
                    try(Row$order[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$order[1],silent=T)
                    try(Row$phylum[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$phylum[1],silent=T)
                    try(Row$kingdom[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Reptilia",]$kingdom[1],silent=T)
                  }
                  if (grepl("Amphibians",unique(Row$Taxon_group))){
                    
                    Row$taxon[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$species[1]
                    
                    Row$scientificName[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$scientificName[1]
                    Row$GBIFstatus[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$status[1]
                    Row$GBIFmatchtype[ind_tax]   <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$matchType[1]
                    Row$GBIFtaxonRank[ind_tax]            <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$rank[1]
                    Row$GBIFusageKey[ind_tax]            <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$usageKey[1]
                    
                    try(Row$species[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$species[1],silent=T)
                    try(Row$genus[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$genus[1],silent=T)
                    try(Row$family[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$family[1],silent=T)
                    try(Row$class[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$class[1],silent=T)
                    try(Row$order[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$order[1],silent=T)
                    try(Row$phylum[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$phylum[1],silent=T)
                    try(Row$kingdom[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Amphibia",]$kingdom[1],silent=T)
                  }
                  if (grepl("Birds",unique(Row$Taxon_group))){
                    
                    Row$taxon[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$species[1]
                    
                    Row$scientificName[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$scientificName[1]
                    Row$GBIFstatus[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$status[1]
                    Row$GBIFmatchtype[ind_tax]   <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$matchType[1]
                    Row$GBIFtaxonRank[ind_tax]        <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$rank[1]
                    Row$GBIFusageKey[ind_tax]        <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$usageKey[1]
                    
                    try(Row$species[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$species[1],silent=T)
                    try(Row$genus[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$genus[1],silent=T)
                    try(Row$family[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$family[1],silent=T)
                    try(Row$class[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$class[1],silent=T)
                    try(Row$order[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$order[1],silent=T)
                    try(Row$phylum[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$phylum[1],silent=T)
                    try(Row$kingdom[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Aves",]$kingdom[1],silent=T)
                  }
                  if (grepl("Insects",unique(Row$Taxon_group))){
                    
                    Row$taxon[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$species[1]
                    
                    Row$scientificName[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$scientificName[1]
                    Row$GBIFstatus[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$status[1]
                    Row$GBIFmatchtype[ind_tax]   <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$matchType[1]
                    Row$GBIFtaxonRank[ind_tax]        <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$rank[1]
                    Row$GBIFusageKey[ind_tax]        <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$usageKey[1]
                    
                    try(Row$species[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$species[1],silent=T)
                    try(Row$genus[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$genus[1],silent=T)
                    try(Row$family[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$family[1],silent=T)
                    try(Row$class[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$class[1],silent=T)
                    try(Row$order[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$order[1],silent=T)
                    try(Row$phylum[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$phylum[1],silent=T)
                    try(Row$kingdom[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Insecta",]$kingdom[1],silent=T)
                  }
                  if (grepl("Mammals",unique(Row$Taxon_group))){
                    
                    Row$taxon[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$species[1]
                    
                    Row$scientificName[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$scientificName[1]
                    Row$GBIFstatus[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$status[1]
                    Row$GBIFmatchtype[ind_tax]   <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$matchType[1]
                    Row$GBIFtaxonRank[ind_tax]        <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$rank[1]
                    Row$GBIFusageKey[ind_tax]        <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$usageKey[1]
                    
                    try(Row$species[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$species[1],silent=T)
                    try(Row$genus[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$genus[1],silent=T)
                    try(Row$family[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$family[1],silent=T)
                    try(Row$class[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$class[1],silent=T)
                    try(Row$order[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$order[1],silent=T)
                    try(Row$phylum[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$phylum[1],silent=T)
                    try(Row$kingdom[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT" & alternatives$class=="Mammalia",]$kingdom[1],silent=T)
                  }
                }
              } # !!!!! new line
            } else {
              
              ## case: a single accepted name in "alternatives" 
              
              Row$taxon[ind_tax] <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$species[1]
              
              Row$scientificName[ind_tax]  <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$scientificName[1]
              Row$GBIFstatus[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$status[1]
              Row$GBIFmatchtype[ind_tax]   <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$matchType[1]
              Row$GBIFtaxonRank[ind_tax]   <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$rank[1]
              Row$GBIFusageKey[ind_tax]    <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$usageKey[1]
              
              Row$GBIFnote[ind_tax]        <- "Accepted name provided in 'alternative names' in GBIF"
              
              try(Row$species[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$species[1],silent=T)
              try(Row$genus[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$genus[1],silent=T)
              try(Row$family[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$family[1],silent=T)
              try(Row$class[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$class[1],silent=T)
              try(Row$order[ind_tax]       <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$order[1],silent=T)
              try(Row$phylum[ind_tax]      <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$phylum[1],silent=T)
              try(Row$kingdom[ind_tax]     <- alternatives[alternatives$status=="ACCEPTED" & alternatives$matchType=="EXACT",]$kingdom[1],silent=T)
              
              next # jump to next taxon
              
            }
          } else if (any(alternatives$status=="SYNONYM" & alternatives$matchType=="EXACT" & any(colnames(alternatives)=="species"))) { # check for synonyms in 'alternatives'
            
            ## check alternative names #################################################################################
            
            if (nrow(alternatives[alternatives$status=="SYNONYM" & alternatives$matchType=="EXACT",])>1) { # check if multiple synonyms are provided; if so leave to next taxon
              Row$GBIFnote[ind_tax] <- "No single accepted name in GBIF" # !!!! new string
              next # not possible to identify correct name
            } 
            
            Row$taxon[ind_tax]       <- alternatives[alternatives$status=="SYNONYM" & alternatives$matchType=="EXACT",]$species[1]
            Row$GBIFstatus[ind_tax]       <- alternatives[alternatives$status=="SYNONYM" & alternatives$matchType=="EXACT",]$status[1]
            Row$GBIFmatchtype[ind_tax]   <- alternatives[alternatives$status=="SYNONYM" & alternatives$matchType=="EXACT",]$matchType[1]
            Row$GBIFtaxonRank[ind_tax]            <- alternatives[alternatives$status=="SYNONYM" & alternatives$matchType=="EXACT",]$rank[1]
            Row$GBIFusageKey[ind_tax]            <- alternatives[alternatives$status=="SYNONYM" & alternatives$matchType=="EXACT",]$usageKey[1]
            
            Row$GBIFnote[ind_tax] <- "Synonym without an exact match of an accepted name on GBIF"  # set as default in this case; potentially over-written in next step
            
            ## try to get author name of synonym (not provided in 'db')
            db_all_2 <- name_backbone_verbose(Row$taxon[ind_tax][1])
            db_2 <- db_all_2[["data"]]
            
            if (db_2$status=="ACCEPTED" & db_2$matchType=="EXACT"){
              
              if (length(unique(db_2[db_2$status=="ACCEPTED" & db_2$matchType=="EXACT",]$family))>1) cat(paste0("\n Warning: Multiple entries of ",Row$scientificName[ind_tax]," found in GBIF! Add author to species name or add kingdom information to original database or check GBIF. \n"))
              
              Row$scientificName[ind_tax] <- db_2[db_2$status=="ACCEPTED" & db_2$matchType=="EXACT",]$scientificName[1]
              
              try(Row$species[ind_tax]     <- db_2[db_2$status=="ACCEPTED" & db_2$matchType=="EXACT",]$species[1],silent=T)
              try(Row$genus[ind_tax]       <- db_2[db_2$status=="ACCEPTED" & db_2$matchType=="EXACT",]$genus[1],silent=T)
              try(Row$family[ind_tax]      <- db_2[db_2$status=="ACCEPTED" & db_2$matchType=="EXACT",]$family[1],silent=T)
              try(Row$class[ind_tax]       <- db_2[db_2$status=="ACCEPTED" & db_2$matchType=="EXACT",]$class[1],silent=T)
              try(Row$order[ind_tax]       <- db_2[db_2$status=="ACCEPTED" & db_2$matchType=="EXACT",]$order[1],silent=T)
              try(Row$phylum[ind_tax]      <- db_2[db_2$status=="ACCEPTED" & db_2$matchType=="EXACT",]$phylum[1],silent=T)
              try(Row$kingdom[ind_tax]     <- db_2[db_2$status=="ACCEPTED" & db_2$matchType=="EXACT",]$kingdom[1],silent=T)
              
              Row$GBIFnote[ind_tax] <- "Accepted name found on GBIF"
            }
            
            next # jump to next taxon
            
          } else {
            mismatches <- rbind(mismatches,c(taxlist[j],NA,NA))
            try(mismatches$status[nrow(mismatches)] <- db$status,silent = T)
            try(mismatches$matchType[nrow(mismatches)] <- db$matchType,silent = T)
          }
          
          # #update progress bar
          # info <- sprintf("%d%% done", round((j/n_taxa)*100))
          # setTxtProgressBar(pb, j, label=info)
        }
        # close(pb)
        
        options(warn=0) # the use of 'tibbles' data frame generates warnings as a bug; if solved this options() should be turned off
        
        # Row <- Row[!is.na(Row$GBIFstatus),] # remove species not resolved in GBIF
        
        out <- list()
        out[[1]] <- Row
        out[[2]] <- mismatches
        
        return(out)
        
      },
      
      error = function(e) {
        
        Row <- dat[x,]
        
        Row$scientificName <- NA
        Row$taxon <- Row$taxon_orig
        Row$GBIFstatus <- "ERROR"
        Row$GBIFmatchtype <- NA
        Row$GBIFnote <- NA
        Row$GBIFstatus_Synonym <- NA
        Row$species <- NA
        Row$genus <- NA
        Row$family <- NA
        Row$class <- NA
        Row$order <- NA
        Row$phylum <- NA
        Row$kingdom <- NA 
        Row$GBIFtaxonRank <- NA
        Row$GBIFusageKey <- NA
        
        mismatches <- data.frame(taxon=NA,status=NA,matchType=NA)
        
        out <- list()
        out[[1]] <- Row
        out[[2]] <- mismatches
        
        return(out)
        
      }
    )
    
  }, mc.cores = setCores)
  
  dat <- purrr::map(MatchNames, 1) %>% dplyr::bind_rows()
  mismatches <- purrr::map(MatchNames, 2) %>% dplyr::bind_rows()

  out <- list()
  out[[1]] <- dat
  out[[2]] <- mismatches

  return(out)
}
