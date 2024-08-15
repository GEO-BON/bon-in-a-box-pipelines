
## Install required packages
packages <- c("rjson","rnaturalearth", "tmaptools", "grDevices", "raster","readr","plyr", "viridis","geojsonsf")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
source(paste(Sys.getenv("SCRIPT_LOCATION"), "Cover loss/customFunctions.R", sep = "/"))

library("rjson")
library('raster')
library("rnaturalearth")
library("tmaptools")
library("grDevices")
library("readr")
library("plyr")
library("viridis")
library("geojsonsf")

### Receiving arguments from input.json.
input <- fromJSON(file=file.path(outputFolder, "input.json"))

### load Inputs
if(file.exists(paste(Sys.getenv("SCRIPT_LOCATION"), input$SDM, sep = "/"))){
  SDM=shapefile(paste(Sys.getenv("SCRIPT_LOCATION"), input$SDM, sep = "/"))
}else{SDM= geojson_sf(input$SDM)}

PDG.TABLE<-read.csv(input$PDG.Table)

###rename PDG.TABLE
colnames(PDG.TABLE)<-1:ncol(PDG.TABLE)
rownames(PDG.TABLE)<-unique(SDM$ID)

### create IDs for SDM
SDM<-as(SDM, 'Spatial')
SDM$ID<-row.names(SDM)
if (is.null(SDM$ID)){
  if(is.null(SDM$DN)){
    SDM$ID<-SDM$FID
  }else{SDM$ID=SDM$DN}
  
}

###Create Colour Palette
CC<-viridis(length(unique(SDM$ID)));names(CC)=unique(SDM$ID)
print(CC)
###set y scale
diff<-PDG.TABLE[1]-PDG.TABLE[22]
y<-round_any((max(diff/PDG.TABLE[,1]))*100, 10, f=ceiling)
###Create plot file
file.out<-file.path(outputFolder, "relative_loss1.pdf")## Script body
{
  PchSizes = seq(0.8,2,length.out=4)
  #AreaClasses = c(0, seq(round_any(min(PDG.TABLE),10, f = ceiling),round_any(max(PDG.TABLE),50), length.out=3), 1000)
  AreaClasses = c(0, 100,500, 1000)
  pdf(file =file.out , width = 60*0.039, height = 70*0.039, useDingbats = F, pointsize = 6, family = 'ArialMT')
  par(mfrow=c(1,1))
  par(mar=c(3,3,1,3))
  plot(NA, xlim=c(1,22), ylim=c(-y,0), axes=F)
  
  # add lines of cells lost by PDG
  for (pdg in rownames(PDG.TABLE)) {
    
    area = as.numeric(PDG.TABLE[pdg,])
    
    perc.lost = (-1+(area[-1]/area[1]))*100

    lines(as.numeric(colnames(PDG.TABLE))[-1], perc.lost, col=adjustcolor(CC[pdg], 0.5), lwd=1)
    
    points(as.numeric(colnames(PDG.TABLE))[-1], perc.lost, col=adjustcolor(CC[pdg], 0.5), pch=16, cex=PchSizes[cut(area, breaks=AreaClasses)])
    
  }
  
  
  # add lines of overall loss of cells
  area.overall = apply(PDG.TABLE, 2, sum)
  perc.lost = (-1+(area.overall[-1]/area.overall[1]))*100
  lines(as.numeric(colnames(PDG.TABLE))[-1], perc.lost, lwd=3, col=adjustcolor(1,0.5))
  axis(2)
  title(ylab='% of area with tree cover loss since 2001', line = 2)
  axis(1, at=seq(1,22,3), labels = seq(2001,2022,3), las=2)
  legend('bottomleft', pch=16, col='grey', legend = paste0(c(paste("<",AreaClasses[2], sep =""),
                                                             paste(AreaClasses[2], AreaClasses[3], sep="-"),
                                                             paste(AreaClasses[3], AreaClasses[4], sep="-"),
                                                             paste(">",AreaClasses[4], sep ="")), ' km2'),
         pt.cex = seq(0.75,3,length.out=5), title='Tree cover area')
  # Add vertical legend on the right with increased margin and larger boxes
  xpos <- 24  # Move legend further to the right
  ypos <- seq(-y, 0, length.out = length(CC))  # Y-positions for the legend
  legend.labels <- names(CC)  # Labels for the legend
  
  for (i in seq_along(CC)) {
    text(xpos, ypos[i], legend.labels[i], col = CC[i], adj = 0, xpd = TRUE, cex = 0.8)
    rect(xpos - 0.95, ypos[i] - 0.5, xpos - 0.5, ypos[i] + 0.5, col = CC[i], border = NA, xpd = TRUE)  # Increase box size
  }
  dev.off()
}


## Outputing result to JSON
output <- list("relative_loss_wcircles"=file.out
    # Add your outputs here "key" = "value"
    # The output keys correspond to those described in the yml file.
    #"error" = "Some error", # halt the pipeline
    #"warning" = "Some warning", # display a warning without halting the pipeline
) 
                
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))
