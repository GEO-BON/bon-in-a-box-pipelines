
####### SInAS workflow: Integration and standardisation of alien species data ###########
##
## Step 2c: Standardisation of taxon names
##
## Replacing taxon names by user-defined list "UserDefinedTaxonNames.xlsx"
##
## Hanno Seebens, Giessen, 17.06.2025
#########################################################################################

# NOTE: This script has been edited from original SInAS verions 

OverwriteTaxonNames <- function(FileInfo=NULL){
  
  ## identify input datasets based on file name "StandardSpec_....csv"
  allfiles <- list.files(file.path("Output/","Intermediate"))
  inputfiles_all <- allfiles[grep("Step4_StandardTaxonNames_",allfiles)]
  inputfiles <- vector()
  for (i in 1:nrow(FileInfo)){
    # inputfiles <- c(inputfiles,grep(FileInfo[i,"Dataset_brief_name"],inputfiles_all,value=T))
    inputfiles <- c(inputfiles,paste("Step4_StandardTaxonNames_",FileInfo[i,"Dataset_brief_name"],".csv",sep=""))
  }
  inputfiles <- inputfiles[!is.na(inputfiles)]
  
  
  ## overwrite taxonomic information ################################################
  
  new_names <- read.xlsx(file.path("Config","UserDefinedTaxonNames.xlsx"))
  fullspeclist <- read.table(file.path("Output","FullTaxaList",paste0(outputfilename,"_",version,"_","FullTaxaList.csv")),stringsAsFactors = F,header=T)
  j = 8
  ## loop over all data sets 
  for (i in 1:length(inputfiles)){ # loop over inputfiles 
    
    dat <- read.table(file.path("Output","Intermediate",inputfiles[i]),header=T,stringsAsFactors = F) %>% 
      tidyr::replace_na(list(scientificName = "TBA"))
    missing <- read.table(file.path("Output","Check",paste0("Missing_Taxa_",FileInfo[i,"Dataset_brief_name"],".csv")),stringsAsFactors=F)[,1]

    
    if (!any(new_names$taxon_orig%in%dat$taxon_orig)) next # jump to next database if no match found
    
    ## replace taxonomic information for each provided new taxon name 
    for (j in 1:nrow(new_names)){
      
      # if (length(unique(dat[dat$taxon_orig==new_names$taxon_orig[j],]$Family))>1 & is.na(new_names$Family[j])){
      #   cat(paste0("\n Warning: Taxon name '",new_names$taxon_orig[j],"' found for more than one family. Add taxonomic information in UserDefinedTaxonNames.xlsx \n"))
      #   next
      # }
      
      if (!any(new_names$taxon_orig[j]%in%dat$taxon_orig)) next # jump to next name if no match found
      
      ## overwrite taxononomic information in individual database files
      dat[dat$taxon_orig==new_names$taxon_orig[j],]$taxon <- new_names$New_taxon[j]
      if (!is.na(new_names$New_scientificName[j])) dat[dat$taxon_orig==new_names$taxon_orig[j],]$scientificName <- new_names$New_scientificName[j]
      
      ## overwrite taxononomic information in full taxon list
      fullspeclist[fullspeclist$taxon_orig==new_names$taxon_orig[j],]$taxon <- new_names$New_taxon[j]
      fullspeclist[fullspeclist$taxon_orig==new_names$taxon_orig[j],]$GBIFstatus <- ""
      if (!is.na(new_names$New_scientificName[j])) fullspeclist[fullspeclist$taxon_orig==new_names$taxon_orig[j],]$scientificName <- new_names$New_scientificName[j]
      if (!is.na(new_names$family[j])) fullspeclist[fullspeclist$taxon_orig==new_names$taxon_orig[j],]$family <- new_names$family[j]
      if (!is.na(new_names$order[j])) fullspeclist[fullspeclist$taxon_orig==new_names$taxon_orig[j],]$order <- new_names$order[j]
      #if (!is.na(new_names$class[j])) fullspeclist[fullspeclist$taxon_orig==new_names$taxon_orig[j],]$class <- new_names$class[j]
      ## fix issue caused by class Actinopterygii being removed from MOL taxonomy (now considered a "gigaclass") so class column missing from GBIF backbone matching + workflow breaks  
      if ("class" %in% colnames(new_names) && !is.na(new_names$class[j])) {fullspeclist[fullspeclist$taxon_orig == new_names$taxon_orig[j], "class"] <- new_names$class[j]}
      if (!is.na(new_names$phylum[j])) fullspeclist[fullspeclist$taxon_orig==new_names$taxon_orig[j],]$phylum <- new_names$phylum[j]
      if (!is.na(new_names$kingdom[j])) fullspeclist[fullspeclist$taxon_orig==new_names$taxon_orig[j],]$kingdom <- new_names$kingdom[j]
      #if (!is.na(new_names$species[j])) fullspeclist[fullspeclist$taxon_orig==new_names$taxon_orig[j],]$species <- new_names$species[j]
      ## fix issue where genus-only taxa e.g. "acacia spp." break workflow 
      if ("species" %in% colnames(new_names) && !is.na(new_names$species[j])) {fullspeclist[fullspeclist$taxon_orig == new_names$taxon_orig[j], "species"] <- new_names$species[j]}
      if (!is.na(new_names$genus[j])) fullspeclist[fullspeclist$taxon_orig==new_names$taxon_orig[j],]$genus <- new_names$genus[j]
      
      if (!is.na(new_names$GBIFstatus[j])) fullspeclist[fullspeclist$taxon_orig==new_names$taxon_orig[j],]$GBIFstatus <- new_names$GBIFstatus[j]
      if (!is.na(new_names$GBIFstatus_Synonym[j])) fullspeclist[fullspeclist$taxon_orig==new_names$taxon_orig[j],]$GBIFstatus_Synonym <- new_names$GBIFstatus_Synonym[j]
      if (!is.na(new_names$GBIFmatchtype[j])) fullspeclist[fullspeclist$taxon_orig==new_names$taxon_orig[j],]$GBIFmatchtype <- new_names$GBIFmatchtype[j]
      if (!is.na(new_names$GBIFtaxonRank[j])) fullspeclist[fullspeclist$taxon_orig==new_names$taxon_orig[j],]$GBIFtaxonRank <- new_names$GBIFtaxonRank[j]
      if (!is.na(new_names$GBIFusageKey[j])) fullspeclist[fullspeclist$taxon_orig==new_names$taxon_orig[j],]$GBIFusageKey <- new_names$GBIFusageKey[j]
      if (!is.na(new_names$GBIFnote[j])) fullspeclist[fullspeclist$taxon_orig==new_names$taxon_orig[j],]$GBIFnote <- new_names$GBIFnote[j]
      
      ## remove taxon name from list of missing taxon names
      if (any(new_names$taxon_orig[j]%in%missing)) missing <- missing[!missing%in%new_names$taxon_orig[j]]
    }
    
    write.table(missing,file.path("Output","Check",paste0("Missing_Taxa_",FileInfo[i,"Dataset_brief_name"],".csv")))
    
    write.table(dat,file.path("Output","Intermediate",paste0("Step4_StandardTaxonNames_",FileInfo[i,"Dataset_brief_name"],".csv")))
  }
  
  
  ## define major taxonomic groups ###################
  fullspeclist$taxaGroup <- NA
  fullspeclist$taxaGroup[fullspeclist$scientificName%in%subset(fullspeclist,class=="Mammalia")$scientificName] <- "Mammals"
  fullspeclist$taxaGroup[fullspeclist$scientificName%in%subset(fullspeclist,class=="Aves")$scientificName] <- "Birds"
  fullspeclist$taxaGroup[fullspeclist$scientificName%in%subset(fullspeclist,class%in%c("Cephalaspidomorphi","Actinopterygii","Elasmobranchii","Sarcopterygii", "Petromyzonti"))$scientificName] <- "Fishes"
  fullspeclist$taxaGroup[fullspeclist$scientificName%in%subset(fullspeclist,order%in%c("Polypteriformes", "Acipenseriformes", "Lepisosteiformes", "Amiiformes", "Osteoglossiformes", "Hiodontiformes", 
                                                                                       "Elopiformes", "Albuliformes", "Notacanthiformes", "Anguilliformes", "Saccopharyngiformes", "Clupeiformes", "Ceratodontiformes",
                                                                                       "Gonorynchiformes", "Cypriniformes", "Characiformes", "Gymnotiformes", "Siluriformes", "Salmoniformes", "Esociformes", 
                                                                                       "Osmeriformes", "Ateleopodiformes", "Stomiiformes", "Aulopiformes", "Myctophiformes", "Lampriformes", "Polymixiiformes", 
                                                                                       "Percopsiformes", "Batrachoidiformes", "Lophiiformes", "Gadiformes", "Ophidiiformes", "Mugiliformes", "Atheriniformes", 
                                                                                       "Beloniformes", "Cetomimiformes", "Cyprinodontiformes", "Stephanoberyciformes", "Beryciformes", "Zeiformes", 
                                                                                       "Gobiesociformes", "Gasterosteiformes", "Syngnathiformes", "Synbranchiformes", "Tetraodontiformes", "Pleuronectiformes", 
                                                                                       "Scorpaeniformes", "Perciformes"))$scientificName] <- "Fishes"
  fullspeclist$taxaGroup[fullspeclist$scientificName%in%subset(fullspeclist,class%in%c("Reptilia", "Testudines","Squamata", "Crocodylia"))$scientificName] <- "Reptiles"
  fullspeclist$taxaGroup[fullspeclist$scientificName%in%subset(fullspeclist,class=="Amphibia")$scientificName] <- "Amphibians"
  fullspeclist$taxaGroup[fullspeclist$scientificName%in%subset(fullspeclist, class%in%c("Insecta"))$scientificName] <- "Insects"
  fullspeclist$taxaGroup[fullspeclist$scientificName%in%subset(fullspeclist, class%in%c("Arachnida", "Pycnogonida"))$scientificName] <- "Arachnids"
  fullspeclist$taxaGroup[fullspeclist$scientificName%in%subset(fullspeclist, class%in%c("Collembola", "Chilopoda", "Diplopoda", "Diplura", "Merostomata", "Pauropoda", "Protura", "Symphyla"))$scientificName] <- "Other arthropods"
  fullspeclist$taxaGroup[fullspeclist$scientific%in%subset(fullspeclist,class%in%c("Branchiopoda","Hexanauplia","Maxillopoda","Ostracoda","Malacostraca", "Copepoda"))$scientificName] <- "Crustaceans"
  fullspeclist$taxaGroup[fullspeclist$scientific%in%subset(fullspeclist,family%in%c("Elminiidae"))$scientificName] <- "Crustaceans"
  fullspeclist$taxaGroup[fullspeclist$scientific%in%subset(fullspeclist,phylum=="Mollusca")$scientificName] <- "Molluscs"
  fullspeclist$taxaGroup[fullspeclist$scientificName %in% subset(fullspeclist, phylum %in% "Tracheophyta")$scientificName] <- "Vascular plants"
  fullspeclist$taxaGroup[fullspeclist$scientificName%in%subset(fullspeclist,phylum%in%c("Bryophyta","Anthocerotophyta", "Marchantiophyta"))$scientificName] <- "Bryophytes"
  fullspeclist$taxaGroup[fullspeclist$scientific%in%subset(fullspeclist,phylum%in%c("Rhodophyta","Chlorophyta","Charophyta","Cryptophyta","Haptophyta"))$scientificName] <- "Algae"
  fullspeclist$taxaGroup[fullspeclist$scientific%in%subset(fullspeclist,phylum%in%c("Ascomycota", "Dothideomycetes", "Sordariomycetes", "Chytridiomycota","Basidiomycota","Microsporidia","Zygomycota", "Entomophthoromycota"))$scientificName] <- "Fungi"
  fullspeclist$taxaGroup[fullspeclist$scientific%in%subset(fullspeclist,phylum%in%c("Actinobacteria","Chlamydiae","Cyanobacteria","Firmicutes","Proteobacteria"))$scientificName |
                           fullspeclist$class == "Ichthyosporea"] <- "Bacteria and protozoans"
  fullspeclist$taxaGroup[fullspeclist$scientific%in%subset(fullspeclist,kingdom%in%c("Bacteria", "Protozoa","Euglenozoa"))$scientificName] <- "Bacteria and protozoans"
  fullspeclist$taxaGroup[fullspeclist$scientific%in%subset(fullspeclist,kingdom%in%c("Viruses"))$scientificName] <- "Viruses"
  fullspeclist$taxaGroup[fullspeclist$scientific%in%subset(fullspeclist,phylum%in%c("Annelida", "Nematoda", "Platyhelminthes", "Sipuncula", "Nemertea", "Onychophora", "Acanthocephala"))$scientificName] <- "Annelids, nematodes, platyhelminthes, and other worms"
  fullspeclist$taxaGroup[fullspeclist$scientific%in%subset(fullspeclist,phylum%in%c("Bryozoa", "Entoprocta", "Chaetognatha", "Cnidaria", "Ctenophora", "Echinodermata", "Phoronida", "Porifera", "Rotifera", "Xenacoelomorpha","Brachiopoda"))$scientificName] <- "Other aquatic animals"
  fullspeclist$taxaGroup[fullspeclist$scientific%in%subset(fullspeclist,class=="Ascidiacea")$scientificName] <- "Other aquatic animals"
  fullspeclist$taxaGroup[fullspeclist$scientificName%in%subset(fullspeclist, phylum%in%c("Foraminifera","Cercozoa","Ciliophora","Ochrophyta","Oomycota","Myzozoa","Peronosporea", "Bigyra"))$scientificName] <- "SAR"
  fullspeclist$taxaGroup[fullspeclist$scientificName%in%subset(fullspeclist, genus%in%c("Plasmodium"))$scientificName] <- "SAR"
  
  # write output
  write.table(fullspeclist,file.path("Output","FullTaxaList",paste0(outputfilename,"_",version,"_","FullTaxaList.csv")),row.names=F)
}