# Script location can be used to access other scripts source
 Sys.getenv("SCRIPT_LOCATION")
print( Sys.getenv("SCRIPT_LOCATION"))

## Install required packages
packages <- c("sf","rjson", 'raster', 'rnaturalearth','tmaptools',"ggOceanMaps", "exactextractr","geojsonsf")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## outputFolder is already defined by server
library("rjson")
library('raster')
library('rnaturalearth')
library('tmaptools')
library("sf")
library("ggOceanMaps")
library("exactextractr")
library("geojsonsf")
source(paste(Sys.getenv("SCRIPT_LOCATION"), "Cover loss/customFunctions.R", sep = "/"))
### Receiving arguments from input.json.
input <- fromJSON(file=file.path(outputFolder, "input.json"))

### Load range
lonRANGE = c(input$bbox[1],input$bbox[3])
latRANGE = c(input$bbox[2],input$bbox[4])
### load SDM
if(file.exists(paste(Sys.getenv("SCRIPT_LOCATION"), input$SDM, sep = "/"))){
  SDM=shapefile(paste(Sys.getenv("SCRIPT_LOCATION"), input$SDM, sep = "/"))
}else{SDM= geojson_sf(input$SDM)}
### Load tree cover in 2000
print(input$tree_cover)
TC = crop(raster(input$tree_cover), c(lonRANGE,latRANGE))

### Load tree cover year loss
print(input$tree_cover_loss)
tree_cover_loss = crop(raster(input$tree_cover_loss), c(lonRANGE,latRANGE))

### add ID to SDM
# if (is.null(SDM$ID)){
#   if(is.null(SDM$DN)){
#     SDM$ID<-SDM$FID
#   }else{SDM$ID=SDM$DN}
#
# }
SDM$ID<-row.names(SDM)
### crop SDM to extent of boundaries
boundary<-c(lonRANGE,latRANGE)
SDM<-clip_shapefile(SDM,boundary)
SDM<-st_cast(SDM, "POLYGON")
SDM<-as(SDM, 'Spatial')
### get binary raster of tree cover loss
tree_cover_loss_bin<-tree_cover_loss>0


###Extract raster values by PDG
#function for returning only raster values instead of also returning coverage fraction
extract_values <- function(values, coverage_fractions) {
  return(values)
}

PDG.TL<-exact_extract(tree_cover_loss,SDM, fun = extract_values)
PDG.TC<-exact_extract(TC,SDM, fun = extract_values)
names(PDG.TC)=SDM$ID
names(PDG.TL)=SDM$ID

### Calculate area of PDGs
AREAS=by(area(SDM)/1000000, SDM$ID, sum)

### Summarize cells of tree-cover-loss by PDG
pdg_table=data.frame(matrix(nrow=0, ncol=23));colnames(pdg_table)=0:22

for (pdg in as.character(unique(SDM$ID))) {
  ### get cells from PDG
  e_PDG.TL=unlist(PDG.TL[names(PDG.TL)==pdg])
  e_PDG.TC=unlist(PDG.TC[names(PDG.TC)==pdg])



  ### get initial tree cover
  tci = AREAS[pdg]*mean(e_PDG.TC)/100 # total area * average tree cover in all pixels

  ### for every year: calculate tree cover loss
  for (y in 1:22) {

    AreaWloss = AREAS[pdg]*mean(e_PDG.TL==y) # fraction of area with tree loss

    CanopyLoss = mean(e_PDG.TC[e_PDG.TL==y])/100 # fraction of canopy loss in area loss

    TotalAreaLoss = AreaWloss*CanopyLoss

    if (is.na(TotalAreaLoss)) {TotalAreaLoss=0}

    tci = c(tci, tci[y]-TotalAreaLoss)

  }

  ### count number of cells per year of loss
  pdg_table[pdg,1:23] = tci

}
###define Path for outputs
tree_cover_loss_bin_p<-file.path(outputFolder, "tree_cover_loss_bin.tif")
pdg_table_p<-file.path(outputFolder, "pdg_table.csv")

### write outputs
write.csv(pdg_table,pdg_table_p, row.names = F)
writeRaster(tree_cover_loss_bin,tree_cover_loss_bin_p, overwrite=TRUE, format = "GTiff")


### Output result to JSON
output <- list("AREAS"=AREAS, "pdg_table"=pdg_table_p, "tree_cover_loss_bin"=tree_cover_loss_bin_p#"cols"=CC
  # Add your outputs here "key" = "value"
  # The output keys correspond to those described in the yml file.
    #"error" = "Some error", # halt the pipeline
    #"warning" = "Some warning", # display a warning without halting the pipeline
)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))
