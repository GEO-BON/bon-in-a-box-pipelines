#packages <- c("raster", "rjson", "geojsonsf", "terra",'sf','rnaturalearth','rnaturalearthdata', 'TeachingDemos','dplyr','plotly','htmlwidgets','colorspace')
#new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
#if(length(new.packages)) install.packages(new.packages)

library(raster)
library(rjson)
library(terra)
library(sf)
library(rnaturalearth)
library(TeachingDemos)
library(dplyr)
library(plotly)
library(geojsonsf)
library(colorspace)

print('loading input data')

## load population polygons, habitat cover map, table of population habitat size
input <- fromJSON(file=file.path(outputFolder, "input.json"))

pop_poly <-st_read(input$population_polygons)
habitat = stack(input$habitat_map)
pop_habitat_area = read.table(input$pop_area, row.names=1, header=T, sep='\t')
ne_nc = input$ne_nc
PDen = input$pop_density

# # # #
# pop_poly = st_read('output/GFS_IndicatorsTool/get_pop_poly/0849da3b1a7f43eb5be94cc1e2070688/population_polygons.geojson')
# habitat = stack('output/GFS_IndicatorsTool/get_LCY/c7c9684dfcdbc58c0e535eb4ca069128/lcyy.tif')
# pop_habitat_area = read.table('output/GFS_IndicatorsTool/pop_area_by_habitat/7b7eec58ceb9a01f9a5bf6e686925a57/pop_habitat_area.tsv', row.names=1, header=T, sep='\t')
# ne_nc = c(0.1)
# PDen = c(500, 1000)



### Set population colors for plotting
set.seed(123);PopCol = darken(sample(rainbow(nrow(pop_habitat_area)), size = nrow(pop_habitat_area), replace = F) , 0.2)
names(PopCol) = rownames(pop_habitat_area)

######### Calculate Ne<500 indicator
print('calculating Ne500 indicator')

# get populations habitat area at last time point
Pop_HA_T = pop_habitat_area[,ncol(pop_habitat_area),drop=F]

# Create table showing populations Ne, calculated using different ne_nc and PDen estimates
ne_table = c()

for (pden in PDen) {

  for (nenc_single_sp in ne_nc) {

      NEs = round(Pop_HA_T*pden*nenc_single_sp)
      ne_table = rbind(ne_table, c(pden, nenc_single_sp, NEs[,1]))


  }
}

ne_table = data.frame(rbind(c('Pden', 'Ne:Nc', rownames(Pop_HA_T)), ne_table))
ne_table_path = file.path(outputFolder, 'NE.tsv')

write.table(ne_table, ne_table_path,
            append = F, row.names = F, col.names = F, sep = "\t", quote=F)


##########  Plot Ne change over time
max_Ne = (max(pop_habitat_area,na.rm=T)*max(PDen)*max(ne_nc))

ne_plot = file.path(outputFolder, 'NE.png')

{
png(filename = ne_plot, width = 1000*length(PDen), height = 1000*length(ne_nc), res = 300)
par(mfrow=c(length(PDen), length(ne_nc)));par(mar=c(3,3,4,1))
for (pden in PDen) {

  for (nenc_single_sp in ne_nc) {

    plot(NA, ylim=range(0,max(c(500,max_Ne))), xlim=c(0,ncol(pop_habitat_area)+1), main=paste0('Pden=',pden,' , Ne:Nc=',nenc_single_sp), axes=F, xlab='', ylab='', xaxs='i', yaxs='i')
    abline(h=(500), lwd=2)

    for (pop in rownames(pop_habitat_area)) {

      lNEs = (round(pop_habitat_area[pop,]*pden*nenc_single_sp))
      lNEs[is.finite(as.numeric(lNEs))==F] = 0


      lines(1:length(lNEs), lNEs, col=adjustcolor(PopCol[pop], 0.7))
      shadowtext(length(lNEs), lNEs[length(lNEs)], pos=2, rownames(lNEs), cex=0.75, col=adjustcolor(PopCol[pop],0.7))

    }

  axis(1, at=1:ncol(pop_habitat_area), labels = colnames(pop_habitat_area), las=2)
  axis(2)
  title(ylab='Ne', line=2)

  }


ggplot()
dev.off()
}
}



##########  Calculate populations mantained
print('calculating PM indicator')

PM = 1-mean(pop_habitat_area[,ncol(pop_habitat_area)][pop_habitat_area[,1]!=0]==0, na.rm=T)


##########  Plot changes in population area

pm_plot = file.path(outputFolder, 'PM.png')

{
  png(filename = pm_plot, width = 2000, height = 1000, res = 300)
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

  rel_pop_habitat_area = as.matrix(pop_habitat_area)/as.numeric(pop_habitat_area[,1])
  rel_pop_habitat_area[is.na(rel_pop_habitat_area)] = 0

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
pop_plot = file.path(outputFolder, 'POP_labels.png')

{
png(pop_plot, width = 1000, height = 1000*LLratio)
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
print('creating interactive map')


### Expand population habitat matrix with intermediary point between years (will facilitate clicking on lines on interactive plots)
ints = round(50/ncol(pop_habitat_area)) # set number of intermediary points between years

# create expanded dataframe with intermediary points
int_pop_habitat_area = data.frame()

for (pop in rownames(pop_habitat_area)) {

  int_area = c(pop_habitat_area[pop,1])

  for (i in 2:ncol(pop_habitat_area)) {

    int_area = c(int_area, seq(pop_habitat_area[pop,i-1], pop_habitat_area[pop,i],length.out=ints)[-1])

  }

  names(int_area) = paste0('int.',1:length(int_area))
  names(int_area)[seq(1, length(int_area), by=ints-1)] = colnames(pop_habitat_area)

  int_pop_habitat_area[pop,names(int_area)] = int_area
}


##### Create a shared data-frame with shapes of populations, Ne over time, Area over time and Relative Area over time.

# Plotly does not allow to click on polygon fills, but only on edges. We therefore split population polygons into a grid to facilitate selection on interactive map.

gridRes = as.numeric(sqrt(sum(st_area(pop_poly)/1000000)/(250))/100) ### grid resolution to obtain ~500 cells

# make grid
grid = st_make_grid(pop_poly, cellsize = c(gridRes,gridRes))
pop_grid = st_intersection(pop_poly, grid)

# create shared dataframe object (force convertion to multipolygon)
merged_DF = st_cast(pop_grid, 'MULTIPOLYGON')



# add colors info
merged_DF$colorsRGB = paste0('rgba(',apply(col2rgb(PopCol[merged_DF$pop]), 2, paste, collapse=','),',0.3)')
merged_DF$colors = PopCol[merged_DF$pop]

# create an empty MultiPolygon geometry (as a "geometry" placeholder in the shared matrix for non-spatial data)
mp = list(list(matrix(0,ncol=2)))
empty_mp = st_sfc(st_multipolygon(mp), crs = crs(pop_poly))


# add estimates of habitat area and NE for different time point, add to merged DF
for (pop in rownames(int_pop_habitat_area)) {

  for (y in colnames(int_pop_habitat_area)) {


    HA = int_pop_habitat_area[pop,y] # total area
    NE = HA*PDen[1]*ne_nc[1] # effective population size estiamate
    HAR = HA / int_pop_habitat_area[pop,1] # relative area


    # Create a new feature with attributes but without geometry
    new_feature <- st_sf(
      pop = pop,
      geometry = empty_mp, # use empty geometry placeholder
      HA = HA,
      NE = NE,
      HAR = (HAR*100)-100,
      TIME = y,
      colors = PopCol[pop],
      colorsRGB = NA
    )

    merged_DF = bind_rows(merged_DF, new_feature)
  }
}

## Format key of merged DF
merged_DF_key = highlight_key(merged_DF, ~pop)


######## Create three polygons describing regions where habitat was lost, increased, or remained stable
HabitatNC = habitat[[1]]==1&habitat[[nlayers(habitat)]]==1;HabitatNC[HabitatNC==0]=NA
HabitatLOSS = habitat[[1]]==1&habitat[[nlayers(habitat)]]==0;HabitatLOSS[HabitatLOSS==0]=NA
HabitatGAIN = habitat[[1]]==0&habitat[[nlayers(habitat)]]==1;HabitatGAIN[HabitatGAIN==0]=NA



### Convert to polygon. If no polygons (e.g. no gain, then return an empty list)
HabitatNC_poly = tryCatch( {fromJSON(sf_geojson(st_as_sf(terra::as.polygons(rast(HabitatNC)))))} , error = function(e) {list()})
HabitatLOSS_poly = tryCatch( {fromJSON(sf_geojson(st_as_sf(terra::as.polygons(rast(HabitatLOSS)))))} , error = function(e) {list()})
HabitatGAIN_poly = tryCatch( {fromJSON(sf_geojson(st_as_sf(terra::as.polygons(rast(HabitatGAIN)))))} , error = function(e) {list()})


######  Map of populations

popMap = plot_ly()  %>%
  # add shapefile layer: boundaries of study area
  add_sf(
    data = st_cast(land,'MULTIPOLYGON'),
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
    showlegend = FALSE,
    line = list(width = 0)
  ) %>%
  # Define Mapbox layout
  layout(mapbox = list(
    style = 'carto-positron',
    zoom = 5,          # Adjust zoom level
    center = list(lon = mean(st_coordinates(st_centroid(pop_poly))[,1]), # Center the map
                  lat = mean(st_coordinates(st_centroid(pop_poly))[,2])),
    layers = list( ## add background layers of habitat change
      list( # habitat gain
        sourcetype = "geojson",
        source = HabitatGAIN_poly,
        below = "traces",
        type = "fill",
        color = "rgba(  136, 200, 254 , 0.6)",
        fill = list(outlinecolor =  "rgba(0,0,0,0)"),
        line = list(width=0)),
      list( # habitat loss
        sourcetype = "geojson",
        source = HabitatLOSS_poly,
        type = "fill",
        fill = list(outlinecolor =  "rgba(0,0,0,0)"),
        below = "traces",
        color = "rgba(  254, 174, 174 , 0.6)",
        line = list(width=0)),
      list( # habitat no change
        sourcetype = "geojson",
        source = HabitatNC_poly,
        type = "fill",
        fill = list(outlinecolor =  "rgba(0,0,0,0)"),
        below = "traces",
        color = "rgba(   174, 251, 137,  0.6)",
        line = list(width=0))
      ),
      domain = list(x = c(0, 1), y = c(0, 1))
  ),
  xaxis=list(),yaxis=list()
  )  %>%
  # Provide your Mapbox token here
  config(mapboxAccessToken = 'your_mapbox_access_token')




####### Build Ne plot over time

ne500line = data.frame('TIME' = colnames(pop_habitat_area), 'ne500' = 500)
NE_plot =   plot_ly(data = merged_DF_key,
                  x= ~TIME,
                  y= ~NE ,
                  hoverinfo = 'text',
                  hoverlabel = list(bgcolor = 'white'),
                  text=~pop,
                  color= ~pop,
                  colors = PopCol[unique(merged_DF$pop)],
                  type = 'scatter', mode='lines') %>%
    add_trace(data = ne500line, x = ~TIME, y = ~ne500, color=I('black'), line = list(width=5, dash='dot')) %>% # add line at ne500
  layout(
    xaxis = list(
      tickvals = which(colnames(int_pop_habitat_area)%in%colnames(pop_habitat_area))-1,  # Custom tick values
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
      tickvals =which(colnames(int_pop_habitat_area)%in%colnames(pop_habitat_area))-1,  # Custom tick values
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
      tickvals = which(colnames(int_pop_habitat_area)%in%colnames(pop_habitat_area))-1,  # Custom tick values
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

NE_matrix = as.matrix(ne_table)
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
pm_plots = plotly::subplot(HA_plot, HAR_plot, nrows=2, titleX = T, titleY = T) %>% hide_legend()

### Get plot title
Title = input$runtitle

### Get rounded NE>500 indicator
ne500r = round(mean(as.numeric(ne_table[2,-c(1:2)])>500, na.rm=T),2)

### Get rounded PM indicator
PMr = round(PM, 2)

# assmeble final interface : map + NE outputs + PM plots
INT = plotly::subplot(popMap, NE_outputs, pm_plots, margin=0.05, titleX =T, titleY = T) %>%
  layout(  annotations = list(
    list(text='Effective population size by Ne:Nc and population density',showarrow=F, x=0.5, y=0.4,xref = "paper",  yref = "paper", xanchor = "center",  yanchor = "bottom" ),
    list(text='<i>Habitat change</i>:',showarrow=F, x=0, y=0, xref = "paper",  yref = "paper", xanchor = "left",  yanchor = "bottom" ),
    list(text='<b>loss</b>',showarrow=F, x=0.1, y=0,  font = list(color = "rgba( 217, 86, 86, 1)"), xref = "paper",  yref = "paper", xanchor = "right",  yanchor = "bottom" ),
    list(text='<b>no ch.</b>',showarrow=F, x=0.12, y=0, font = list(color = "rgba(  73, 208, 76, 1)"), xref = "paper",  yref = "paper", xanchor = "center",  yanchor = "bottom" ),
    list(text='<b>gain</b>',showarrow=F, x=0.14, y=0, font = list(color = "rgba( 69, 149, 218, 1)"), xref = "paper",  yref = "paper", xanchor = "left",  yanchor = "bottom" )
      ),
    title=paste0(Title,'<br>Ne500 Indicator = ',ne500r,'; Populations Maintained Indicator = ', PMr),
    margin = 0.05)


pathInteractive = file.path(outputFolder, 'interactive_plot.html')
htmlwidgets::saveWidget(INT, pathInteractive)

# Output Ne500 value


## Write output

output <- list('interactive_plot'= pathInteractive,
'ne_table'= ne_table_path,
'ne500'= ne500r,
'pm' = PM
)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))


