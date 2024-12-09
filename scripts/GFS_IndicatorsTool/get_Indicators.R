#packages <- c("rjson", "geojsonsf", "terra",'sf','rnaturalearth','rnaturalearthdata', 'TeachingDemos','dplyr','plotly','htmlwidgets','colorspace')
#new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
#if(length(new.packages)) install.packages(new.packages)

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

pop_habitat_area = read.table(input$pop_area, row.names=1, header=T, sep='\t')
ne_nc = input$ne_nc
PDen = input$pop_density

#import habitat change maps for plotting
output_maps<-input$cover_maps
HabitatNC=rast(paste0(output_maps, "/HabitatNC.tif"))
HabitatLOSS=rast(paste0(output_maps, "/HabitatLOSS.tif"))
HabitatGAIN=rast(paste0(output_maps, "/HabitatGAIN.tif"))

# # # # #
# pop_poly = st_read('output/GFS_IndicatorsTool/get_pop_poly/9b39fc6dfd1badbee9e004a0aeffc008/population_polygons.geojson')
# habitat = stack('output/GFS_IndicatorsTool/get_LCY/4d75a04ceef2cb0acbdf4564ee1f22da/lcyy.tif')
# pop_habitat_area = read.table('output/GFS_IndicatorsTool/pop_area_by_habitat/1b0d13bac38e3c6a8381352186ebc447/pop_habitat_area.tsv', row.names=1, header=T, sep='\t')
# ne_nc = c(0.1)
# PDen = c(1000)

##Input control:
if (!all(st_bbox(HabitatGAIN)==st_bbox(HabitatLOSS)) | !all(st_bbox(HabitatGAIN)==st_bbox(HabitatNC)) | !all(st_bbox(HabitatLOSS)== st_bbox(HabitatNC))){
  stop("\n**************************************\n",
       "*** ERROR: COVER MAPS NOT MATCHING ***\n",
       "**************************************\n",
       "Error Message: Cover maps not matching. Check Habitat files in cover map folder \n\n")
}

if(!all(round(st_bbox(pop_poly),1 )==round(st_bbox(HabitatGAIN), 1))) {
  
  stop("\n***************************************************************\n",
       "*** ERROR: POPULATION POLYGONS AND COVER MAPS DON'T OVERLAP ***\n",
       "***************************************************************\n",
       "Error Message: Population polygons don't overlap with Cover maps. Check extent of input files.\n\n")
  stop("Error: the population polygons dont overlap with the cover maps. Check input")
  
  
}

if( any(ne_nc>1)){
  stop("\n**************************************\n",
       "*** ERROR: NE:NC RATIO NOT CORRECT ***\n",
       "**************************************\n",
       "Error Message: Ne:Nc ratio cant be above 1 \n\n")
}

### Set population colors for plotting
set.seed(123);PopCol = darken(sample(rainbow(nrow(pop_habitat_area)), size = nrow(pop_habitat_area), replace = F) , 0.2)
names(PopCol) = rownames(pop_habitat_area)

######### Calculate Ne<500 indicator
print('calculating Ne500 indicator')

# get minimal populations habitat area over time
Pop_HA_T = as.matrix(apply(pop_habitat_area,1,min))

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




##########  Calculate populations mantained
print('calculating PM indicator')

PM = 1-mean(pop_habitat_area[,ncol(pop_habitat_area)][pop_habitat_area[,1]!=0]==0, na.rm=T)



# get land polygons for plotting
sf_use_s2(F)
land = st_crop(rnaturalearth::ne_countries(scale = 'large'), st_bbox(pop_poly))
#land=st_bbox
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
  
  HA_min_past = int_pop_habitat_area[pop,1] # set minimal habitat area observed in past (set first year to start) 
  
  for (y in colnames(int_pop_habitat_area)) {
    
    HA = int_pop_habitat_area[pop,y] # total area
    NE = min(c(HA,HA_min_past))*PDen[1]*ne_nc[1] # effective population size estiamate, if there is an area increase, uses minimal past area (area decline decrease Ne, but area expansion does not increase Ne)
    HAR = HA / int_pop_habitat_area[pop,1] # relative area
    
    # update HA_min_past
    HA_min_past = min(c(HA, HA_min_past))
    
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


### Convert to polygon. If no polygons (e.g. no gain, then return an empty list)
HabitatNC_poly = tryCatch( {fromJSON(sf_geojson(st_as_sf(terra::as.polygons((HabitatNC)))))} , error = function(e) {list()})
HabitatLOSS_poly = tryCatch( {fromJSON(sf_geojson(st_as_sf(terra::as.polygons((HabitatLOSS)))))} , error = function(e) {list()})
HabitatGAIN_poly = tryCatch( {fromJSON(sf_geojson(st_as_sf(terra::as.polygons((HabitatGAIN)))))} , error = function(e) {list()})



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


