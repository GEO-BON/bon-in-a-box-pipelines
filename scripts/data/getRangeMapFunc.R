if (!"gdalUtilities" %in% installed.packages()[,"Package"]) install.packages("gdalUtilities")
library(gdalUtilities)

setwd(outputFolder)
get_iucn_range_map <- function(species_name){
  species_map<-read.csv('https://object-arbutus.alliancecan.ca/86e1f3d5df8442d39450533329f621ae:stac/IUCN_rangemaps/iucn_fid_binomials.csv')
  row=species_map |> subset(binomial == species_name)
  for(r in row$fid){
    ogr2ogr(paste0('/vsicurl/https://object-arbutus.alliancecan.ca/86e1f3d5df8442d39450533329f621ae:stac/IUCN_rangemaps/',row$FIELD_4),paste0(species_name,'_range.gpkg'),fid=r,append=TRUE)
  }
}

get_mol_range_map <- function(species_name){
  species_map<-read.csv('https://object-arbutus.alliancecan.ca/86e1f3d5df8442d39450533329f621ae:stac/mol_range_maps/mol_mammals.csv')
  row=species_map |> subset(sciname == species_name)
  for(r in row$fid){
    ogr2ogr('/vsicurl/https://object-arbutus.alliancecan.ca/86e1f3d5df8442d39450533329f621ae:stac/mol_range_maps/mol_mammals.fgb',paste0(species_name,'_mol_range.gpkg'),fid=r,append=TRUE,update=TRUE)
  }
}

get_qc_range_map <- function(species_name){
  species_map<-read.csv('https://object-arbutus.alliancecan.ca/86e1f3d5df8442d39450533329f621ae:stac/qc_range_maps/qc_range_maps.csv')
  species_map$NOM_SCIENT<-stringi::stri_trans_general(species_map$NOM_SCIENT, "latin-ascii")
  row=species_map |> subset(NOM_SCIENT == species_name)
  for(r in row$fid){
    ogr2ogr('/vsicurl/https://object-arbutus.alliancecan.ca/86e1f3d5df8442d39450533329f621ae:stac/qc_range_maps/qc_range_maps.fgb',paste0(species_name,'_qc_range.gpkg'),fid=r,append=TRUE,update=TRUE)
  }
}