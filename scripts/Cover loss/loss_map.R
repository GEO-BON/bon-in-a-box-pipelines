### Install required packages
packages <- c("rjson","rnaturalearth", "tmaptools", "grDevices", "raster", "geojsonsf", "viridis")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
source(paste(Sys.getenv("SCRIPT_LOCATION"), "Cover loss/customFunctions.R", sep = "/"))
library("rjson")
library('raster')
library("rnaturalearth")
library("tmaptools")
library("grDevices")
library("geojsonsf")
library("viridis")
### Receiving arguments from input.json.
input <- fromJSON(file=file.path(outputFolder, "input.json"))

### Load Inputs
lonRANGE = c(input$bbox[1],input$bbox[3])
latRANGE = c(input$bbox[2],input$bbox[4])
tree_cover_loss=raster(input$tree_cover_loss)
geoLabels = geocode_OSM(input$geoLabels)
tree_cover_loss_bin = raster(input$tree_cover_loss_bin)
if(file.exists(paste(Sys.getenv("SCRIPT_LOCATION"), input$SDM, sep = "/"))){
  SDM=shapefile(paste(Sys.getenv("SCRIPT_LOCATION"), input$SDM, sep = "/"))
}else{SDM= geojson_sf(input$SDM)}
### find pixels with canopy cover > 30% (for plotting)
TC30 = raster(input$tree_cover)>30
### Create SDM IDs
SDM<-as(SDM, 'Spatial')
SDM$ID<-row.names(SDM)
if (is.null(SDM$ID)){
  if(is.null(SDM$DN)){
    SDM$ID<-SDM$FID
  }else{SDM$ID=SDM$DN}

}
###Create Color pallette
CC<-viridis(length(unique(SDM$ID)));names(CC)=unique(SDM$ID)
print(CC)
## Script body
map<-file.path(outputFolder, "map.pdf")
{
  ### Plot tree cover loss vs. PDG in study area
  pdf(file = map, width = 1.56*diff(lonRANGE), height = 1.56*diff(latRANGE), useDingbats = F, pointsize = 6, family = 'ArialMT')
  par(mfrow=c(1,1))
  par(mar=c(0,0,0,0))
  plot(NA, xlim=lonRANGE, ylim=latRANGE, axes=F, xaxs='i', yaxs='i')
  plot(TC30, col=c('white','lightgreen'), add=T, legend=F)
  plot(tree_cover_loss_bin, col=c(NA, adjustcolor('red2',0.5)), add=T, legend=F)

  plot(SDM, border=CC[as.character(SDM$ID)], col=adjustcolor(CC[as.character(SDM$ID)], 0.1), lwd=3,  add=T)
  text(geoLabels$lon, geoLabels$lat,  geoLabels$query, cex=2, col=adjustcolor(1,0.2))
  Scalebar(lbar = 50, bar.text = '50 km', xpos = 0.50, ypos=0.1)
  dev.off()
}
### Outputing result to JSON

output <- list("map"=map)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))