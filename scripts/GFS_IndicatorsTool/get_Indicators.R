packages <- c("raster", "rjson", "geojsonsf", "terra",'sf','rnaturalearth','rnaturalearthdata', 'TeachingDemos')
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
if(!"rgdal"%in% installed.packages()){
  install.packages("rgdal", repos="http://R-Forge.R-project.org", type="source") 
}
if(!"gdalUtils"%in% installed.packages()){
  library(devtools)
  devtools::install_github("gearslaboratory/gdalUtils")
}
library(raster)
library(gdalUtils)
library(rjson)
library(terra)
library(sf)
library(rnaturalearth)
library(TeachingDemos)

## load population polygons, habitat cover map, table of population habitat size
input <- fromJSON(file=file.path(outputFolder, "input.json"))

pop_poly <-st_read(input$population_polygons)
habitat = stack(input$habitat_map)
pop_habitat_area = read.table(input$popArea, row.names=1, header=T, sep='\t')
NeNc = input$NeNc
PDen = input$PopDensity

# pop_poly = st_read('userdata/populations.geojson')
# habitat = stack('userdata/TCY.tif')
# pop_habitat_area = read.table('output/GFS_IndicatorsTool/pop_area_by_habitat/16e45a3e3d46dfb96c20619b0a0cdba4/pop_habitat_area.tsv', row.names=1, header=T, sep='\t')
# NeNc = c(0.05,0.1,0.5)
# PDen = c(50, 100, 500)


### Set population colors for plotting
set.seed(123);PopCol = sample(rainbow(nrow(pop_habitat_area)), size = nrow(pop_habitat_area), replace = F) 
names(PopCol) = rownames(pop_habitat_area)

######### Calculate Ne<500 indicator

# get populations habitat area at last time point
Pop_HA_T = pop_habitat_area[,ncol(pop_habitat_area),drop=F]

# Create table showing populations Ne, calculated using different NeNC and PDen estimates
NE_table = c()

for (pden in PDen) {
  
  for (nenc in NeNc) {
    
      NEs = round(Pop_HA_T*pden*nenc)
      NE_table = rbind(NE_table, c(pden, nenc, NEs[,1]))
    
    
  }
}

NE_table = data.frame(rbind(c('Pden', 'Ne:Nc', rownames(Pop_HA_T)), NE_table))
NE_table_path = file.path(outputFolder, 'NE.tsv')

write.table(NE_table, NE_table_path,
            append = F, row.names = F, col.names = F, sep = "\t", quote=F)


##########  Plot Ne change over time
max_Ne = log(max(pop_habitat_area)*max(PDen)*max(NeNc))

Ne_plot = file.path(outputFolder, 'NE.png')

{
png(filename = Ne_plot, width = 1000*length(PDen), height = 1000*length(NeNc), res = 300)
par(mfrow=c(length(PDen), length(NeNc)));par(mar=c(3,3,4,1))
for (pden in PDen) {
  
  for (nenc in NeNc) {
    
    plot(NA, ylim=range(0,max_Ne), xlim=c(0,ncol(pop_habitat_area)+1), main=paste0('Pden=',pden,' , Ne:Nc=',nenc), axes=F, xlab='', ylab='', xaxs='i', yaxs='i')
    abline(h=log(500), lwd=2)
    
    for (pop in rownames(pop_habitat_area)) {
    
      lNEs = log(round(pop_habitat_area[pop,]*pden*nenc))
      lNEs[is.finite(as.numeric(lNEs))==F] = 0
      
      
      lines(1:length(lNEs), lNEs, col=adjustcolor(PopCol[pop], 0.7))
      shadowtext(length(lNEs), lNEs[length(lNEs)], pos=2, rownames(lNEs), cex=0.75, col=adjustcolor(PopCol[pop],0.7))
      
    } 
    
  axis(1, at=1:ncol(pop_habitat_area), labels = colnames(pop_habitat_area), las=2)
  axis(2)
  title(ylab='log(Ne)', line=2)  
    
  }
  

}
dev.off()
}


##########  Calculate populations mantained

PM = 1-mean(pop_habitat_area[,ncol(pop_habitat_area)][pop_habitat_area[,1]!=0]==0)


##########  Plot changes in population area

PM_plot = file.path(outputFolder, 'PM.png')

{
  png(filename = PM_plot, width = 2000, height = 1000, res = 300)
  par(mfrow=c(1,2));par(mar=c(3,3,3,2))
  
  ### Plot population habitat area over time
  plot(NA, ylim=c(0,max(pop_habitat_area)), xlim=c(0,ncol(pop_habitat_area)+1), main='Pop. Area [km2]', axes=F, xlab='', ylab='', xaxs='i', yaxs='i')
  
  for (pop in rownames(pop_habitat_area)) {
        lines(1:ncol(pop_habitat_area), pop_habitat_area[pop,], col=adjustcolor(PopCol[pop], 0.7))
        shadowtext(ncol(pop_habitat_area), pop_habitat_area[pop,ncol(pop_habitat_area)], pos=2, pop, cex=0.75, col=adjustcolor(PopCol[pop],0.7))
      } 
      axis(1, at=1:ncol(pop_habitat_area), labels = colnames(pop_habitat_area), las=2)
      axis(2)
      title(ylab='area [km2]', line=2)  
    
    
  ### Plot relative change in population habitat area over time
  
  rel_pop_habitat_area = na.omit(as.matrix(pop_habitat_area)/as.numeric(pop_habitat_area[,1]))
      

  plot(NA, ylim=c(0,max(rel_pop_habitat_area,na.rm=T)), xlim=c(0,ncol(rel_pop_habitat_area)+1), main='Rel. Pop. Area', axes=F, xlab='', ylab='', xaxs='i', yaxs='i')

  for (pop in rownames(rel_pop_habitat_area)) {
    lines(1:ncol(rel_pop_habitat_area), rel_pop_habitat_area[pop,], col=adjustcolor(PopCol[pop], 0.7))
    shadowtext(ncol(rel_pop_habitat_area), rel_pop_habitat_area[pop,ncol(pop_habitat_area)], pos=2, pop, cex=0.75, col=adjustcolor(PopCol[pop],0.7))
  } 
  axis(1, at=1:ncol(rel_pop_habitat_area), labels = colnames(rel_pop_habitat_area), las=2)
  axis(2)
  title(ylab='% area change', line=2)  

  dev.off()
}


##########  Display populations maps
sf_use_s2(F)

# get land polygons for plotting
land = st_crop(ne_countries(scale = 'large') , extent(habitat))

# calculate bg map of habitat loss
HabitatLoss = habitat[[1]]==1&habitat[[nlayers(habitat)]]==0

# get coordinates of population labels
pop_coord = st_coordinates(st_centroid(pop_poly))

# set position of labels for popualtions at edges of map
lab_pos = rep(1, nrow(pop_coord))
lab_pos[which.min(pop_coord[,1])] = 4
lab_pos[which.max(pop_coord[,1])] = 2
lab_pos[which.min(pop_coord[,2])] = 3

# calculate lon-lat ratio for map proportions 
LLratio = nrow(HabitatLoss)/ncol(HabitatLoss)

# set figure path
POP_plot = file.path(outputFolder, 'POP_labels.png')

{
png(POP_plot, width = 1000, height = 1000*LLratio)
par(mar=c(0,0,0,0))
plot(NA, xlim=extent(HabitatLoss)[1:2], ylim=extent(HabitatLoss)[3:4], xaxs='i', yaxs='i')
plot(HabitatLoss, add=T, legend=F, col=c('white','pink'))
plot(land, border='grey70', col=adjustcolor('grey90',0.2), add=T)
plot(pop_poly, add=T, border=NA, col=PopCol)
shadowtext(pop_coord[,1], pop_coord[,2], pop_poly$pop, col=PopCol, cex=3, pos=lab_pos)
box()
dev.off()
}




## Write output


output <- list("Ne_table" = NE_table_path, "Ne_plot"=Ne_plot, 'PM'=PM, 'PM_plot'=PM_plot, 'POP_plot'=POP_plot) 
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

