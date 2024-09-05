packages <- c("raster", "rjson", "geojsonsf", "terra",'sf','rnaturalearth','rnaturalearthdata', 'TeachingDemos','dplyr','plotly','htmlwidgets')
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
library(dplyr)
library(plotly)

print('loading input data')

## load population polygons, habitat cover map, table of population habitat size
input <- fromJSON(file=file.path(outputFolder, "input.json"))

pop_poly <-st_read(input$population_polygons)
habitat = stack(input$habitat_map)
pop_habitat_area = read.table(input$popArea, row.names=1, header=T, sep='\t')
NeNc = input$NeNc
PDen = input$PopDensity


# pop_poly = st_read('output/GFS_IndicatorsTool/get_pop_poly/3515605c5e6c39dd27e7f2cf24574463/population_polygons.geojson')
# habitat = stack('userdata/grasslands.tif')
# pop_habitat_area = read.table('output/GFS_IndicatorsTool/pop_area_by_habitat/07cfe8878729ea8a5faad3acacb5db63/pop_habitat_area.tsv', row.names=1, header=T, sep='\t')
# NeNc = c(0.1)
# PDen = c(500)


### Set population colors for plotting
set.seed(123);PopCol = sample(rainbow(nrow(pop_habitat_area)), size = nrow(pop_habitat_area), replace = F) 
names(PopCol) = rownames(pop_habitat_area)


######### Calculate Ne<500 indicator
print('calculating Ne500 indicator')

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
max_Ne = log(max(pop_habitat_area,na.rm=T)*max(PDen)*max(NeNc))

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
print('calculating PM indicator')

PM = 1-mean(pop_habitat_area[,ncol(pop_habitat_area)][pop_habitat_area[,1]!=0]==0, na.rm=T)


##########  Plot changes in population area

PM_plot = file.path(outputFolder, 'PM.png')

{
  png(filename = PM_plot, width = 2000, height = 1000, res = 300)
  par(mfrow=c(1,2));par(mar=c(3,3,3,2))
  
  ### Plot population habitat area over time
  plot(NA, ylim=c(0,max(pop_habitat_area, na.rm=T)), xlim=c(0,ncol(pop_habitat_area)+1), main='Pop. Area [km2]', axes=F, xlab='', ylab='', xaxs='i', yaxs='i')
  
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

# calculate bg map of habitat at first and last time point
HabitatT0 = habitat[[1]]==1
HabitatT1 = habitat[[nlayers(habitat)]]==1
HabitatT0[HabitatT0==0] = NA
HabitatT1[HabitatT1==0] = NA

# get coordinates of population labels
pop_coord = st_coordinates(st_centroid(pop_poly))

# set position of labels for popualtions at edges of map
lab_pos = rep(1, nrow(pop_coord))
lab_pos[which.min(pop_coord[,1])] = 4
lab_pos[which.max(pop_coord[,1])] = 2
lab_pos[which.min(pop_coord[,2])] = 3

# calculate lon-lat ratio for map proportions 
LLratio = nrow(HabitatT0)/ncol(HabitatT0)

# set figure path
POP_plot = file.path(outputFolder, 'POP_labels.png')

{
png(POP_plot, width = 1000, height = 1000*LLratio)
par(mar=c(0,0,0,0))
plot(NA, xlim=extent(HabitatT0)[1:2], ylim=extent(HabitatT0)[3:4], xaxs='i', yaxs='i')
plot(HabitatT0, add=T, legend=F, col=adjustcolor('green2',0.2))
plot(HabitatT1, add=T, legend=F, col=adjustcolor('green4',0.2))
plot(land, border='grey70', col=adjustcolor('grey90',0.2), add=T)
plot(pop_poly, add=T, border=NA, col=PopCol)
shadowtext(pop_coord[,1], pop_coord[,2], pop_poly$pop, col=PopCol, cex=3, pos=lab_pos)
box()
dev.off()
}





######################## Create interactive plotly output
##### Create a shared data-frame with shapes of populations, Ne over time, Area over time and Relative Area over time.
print('creating interactive map')

# add shapes of populations
merged_DF = pop_poly

# add colors info
merged_DF$colorsRGB = paste0('rgba(',apply(col2rgb(PopCol[merged_DF$pop]), 2, paste, collapse=','),',0.3)')
merged_DF$colors = PopCol[merged_DF$pop]

# create an empty MultiPolygon geometry (as a "geometry" placeholder in the shared matrix for non-spatial data)
mp = list(list(matrix(0,ncol=2)))
empty_mp = st_sfc(st_multipolygon(mp), crs = crs(pop_poly))


# add estimates of habitat area and NE for different time point, add to merged DF
for (pop in rownames(pop_habitat_area)) {

  for (y in colnames(pop_habitat_area)) {

    
    HA = pop_habitat_area[pop,y] # total area
    NE = HA*PDen[1]*NeNc[1] # effective population size estiamate
    HAR = HA / pop_habitat_area[pop,1] # relative area


    # Create a new feature with attributes but without geometry
    new_feature <- st_sf(
      pop = pop,
      geometry = empty_mp, # use empty geometry placeholder
      HA = HA,
      NE = NE,
      HAR = HAR,
      TIME = y,
      colors = PopCol[pop],
      colorsRGB = NA
    )

    merged_DF = bind_rows(merged_DF, new_feature)
  }
}

## Format key of merged DF
merged_DF_key = highlight_key(merged_DF, ~pop)


######## Transform habitat at first and last timepoint from rasters to polygons
HabitatT0_poly = st_as_sf(terra::as.polygons(rast(HabitatT0)))
HabitatT1_poly = st_as_sf(terra::as.polygons(rast(HabitatT1)))



######  Map of populations

popMap = plot_ly()  %>%
  #Add the shapefile layer: habitat loss
  add_sf(
    data = HabitatT0_poly,
    type = "scattermapbox",
    mode = "lines",
    hoverinfo = 'none',
    fillcolor = 'rgba(183, 247, 163,0.3)',
    line = list(width = 0)
  ) %>%
  add_sf(
    data = HabitatT1_poly,
    type = "scattermapbox",
    mode = "lines",
    hoverinfo = 'none',
    fillcolor = 'rgba(87, 133, 73,0.3)',
    line = list(width = 0)
  ) %>%
  # add shapefile layer: boundaries of study area
  add_sf(
    data = land,
    type = "scattermapbox",
    mode = "lines",
    hoverinfo = 'none',
    fillcolor = 'rgba(0,0,0,0)',
    line = list(width = 1, color='grey')
  ) %>%
  #Add the shapefile layer: population polygons
  add_sf(
    data = merged_DF_key,
    type = "scattermapbox",
    mode = "lines",
    hoverinfo = 'text',
    hoverlabel = list(bgcolor = 'white'),
    text=~pop,
    fillcolor = ~colorsRGB,
    line = list(width = 1, color='grey')
  ) %>% 
  # Define Mapbox layout with your Mapbox access token
  layout(mapbox = list(
    style = 'carto-positron',  
    zoom = 5,          # Adjust zoom level
    center = list(lon = mean(st_coordinates(st_centroid(pop_poly))[,1]), # Center the map
                  lat = mean(st_coordinates(st_centroid(pop_poly))[,2])),
    domain = list(x = c(0, 1), y = c(0, 1)) # set size  on interface
  ),
  xaxis=list(),yaxis=list()
  )  %>%
  # Provide your Mapbox token here
  config(mapboxAccessToken = 'your_mapbox_access_token') %>% hide_legend()



####### Build Ne plot over time

NE_plot = plot_ly(data = merged_DF_key,
                  x= ~TIME,
                  y= ~NE ,
                  hoverinfo = 'text',
                  hoverlabel = list(bgcolor = 'white'),
                  text=~pop,
                  color= ~pop,
                  colors = PopCol[unique(merged_DF$pop)],
                  type = 'scatter', mode='lines') %>%
  layout(
    xaxis = list(
      tickvals = 0:ncol(pop_habitat_area),  # Custom tick values
      type='categorical',
      title = 'time',
      showgrid = TRUE,      # Show grid lines (optional)
      zeroline = TRUE,      # Show zero line (optional)
      showline = TRUE,      # Show axis line
      showticklabels = TRUE # Show axis tick labels
    ),
    yaxis = list(
      title = 'Effective population size',
      showgrid = TRUE,      # Show grid lines (optional)
      zeroline = TRUE,      # Show zero line (optional)
      showline = TRUE,      # Show axis line
      showticklabels = TRUE, # Show axis tick labels
      domain = c(0.1,0.9)
    )
  ) %>% hide_legend()





####### Build Habitat size over time

HA_plot = plot_ly(data = merged_DF_key,
                  x= ~TIME,
                  y= ~HA ,
                  hoverinfo = 'text',
                  hoverlabel = list(bgcolor = 'white'),
                  text=~pop,
                  color= ~pop,
                  colors = PopCol[unique(merged_DF$pop)],
                  type = 'scatter', mode='lines') %>%
  layout(
    xaxis = list(
      tickvals = 0:ncol(pop_habitat_area),  # Custom tick values
      type='categorical',
      title = 'time',
      showgrid = TRUE,      # Show grid lines (optional)
      zeroline = TRUE,      # Show zero line (optional)
      showline = TRUE,      # Show axis line
      showticklabels = TRUE # Show axis tick labels
    ),
    yaxis = list(
      title = 'Habitat Size [km2]',
      showgrid = TRUE,      # Show grid lines (optional)
      zeroline = TRUE,      # Show zero line (optional)
      showline = TRUE,      # Show axis line
      showticklabels = TRUE, # Show axis tick labels
      domain = c(0.1,0.9)
    )
  ) %>% hide_legend() 






####### Build Realtive habitat size over time

HAR_plot = plot_ly(data = merged_DF_key,
                  x= ~TIME,
                  y= ~HAR ,
                  hoverinfo = 'text',
                  hoverlabel = list(bgcolor = 'white'),
                  text=~pop,
                  color= ~pop,
                  colors = PopCol[unique(merged_DF$pop)],
                  type = 'scatter', mode='lines') %>%
  layout(
    xaxis = list(
      tickvals = 0:ncol(pop_habitat_area),  # Custom tick values
      type='categorical',
      title = 'time',
      showgrid = TRUE,      # Show grid lines (optional)
      zeroline = TRUE,      # Show zero line (optional)
      showline = TRUE,      # Show axis line
      showticklabels = TRUE # Show axis tick labels
    ),
    yaxis = list(
      title = 'Relative change in Habitat Size [%]',
      showgrid = TRUE,      # Show grid lines (optional)
      zeroline = TRUE,      # Show zero line (optional)
      showline = TRUE,      # Show axis line
      showticklabels = TRUE, # Show axis tick labels
      domain = c(0.1,0.9)
    )
  ) %>% hide_legend()


####### Build Ne table over time by Ne:Nc and Pden estimate

NE_matrix = as.matrix(NE_table)
NE_matrix[is.na(NE_matrix)] = '-'

NE_mat =  plot_ly(
  domain = list(x=c(0.33,0.66), y=c(0,0.4)),
  type = 'table',
  header = list(
    values = paste0(NE_matrix[,1],'<br>',NE_matrix[,2]),
    line = list(color = '#506784'),
    fill = list(color = '#119DFF'),
    align = c('center'),
    font = list(color = 'white', size = 12)
  ),
  cells = list(
    values = as.matrix(NE_matrix[,-c(1:2)]),
    line = list(color = '#506784'),
    fill = list(color = c('blue','#dadada','white')),
    align = c('center'),
    font = list(color = c('white','#506784'), size = 12)
  ))



########## Assemble interactive interface

# merge NE plot and NE table
NE_outputs = plotly::subplot(NE_plot, NE_mat, nrows=2, titleX = T, titleY = T) %>% hide_legend()

# merge PM plots
PM_plots = plotly::subplot(HA_plot, HAR_plot, nrows=2, titleX = T, titleY = T) %>% hide_legend()

### Get plot title
Title = input$RunTitle

### Get rounded NE>500 indicator
NE500r = round(mean(as.numeric(NE_table[2,-c(1:2)])>500, na.rm=T),2)

### Get rounded PM indicator
PMr = round(PM, 2)

# assmeble final interface : map + NE outputs + PM plots
INT = plotly::subplot(popMap, NE_outputs, PM_plots, margin=0.05, titleX =T, titleY = T) %>% 
  layout(  annotations = list(list(text='Effective population size by Ne:Nc and population density',showarrow=F, x=0.5, y=0.4,xref = "paper",  yref = "paper", xanchor = "center",  yanchor = "bottom" )),
    title=paste0(Title,'<br>Ne500 Indicator = ',NE500r,'; Populations Maintained Indicator = ',PMr),
    margin = 0.05)


pathInteractive = file.path(outputFolder, 'interactive_plot.html')
htmlwidgets::saveWidget(INT, pathInteractive)



## Write output


output <- list("Ne_table" = NE_table_path, "Ne_plot"=Ne_plot, 'PM'=PM, 'NE500',NE500r, 'PM_plot'=PM_plot, 'POP_plot'=POP_plot, 'Interactive_plot'= pathInteractive) 
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))

