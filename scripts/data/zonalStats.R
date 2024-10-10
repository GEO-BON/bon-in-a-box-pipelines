## This is a script to load layers from the STAC catalog and calculate zonal statistics for a polygon (country or region) of interest
## Modified from Load From STAC

library("rjson")
library("dplyr")
library("gdalcubes")
library("sf")
sf_use_s2(FALSE)

# load from STAC function to load data cube
source(paste(Sys.getenv("SCRIPT_LOCATION"), "/data/loadFromStacFun.R", sep = "/"))

input <- fromJSON(file=file.path(outputFolder, "input.json"))

output<- tryCatch({
# Collections items
if (length(input$collections_items) == 0) {
    stop('Please specify collections_items') # if no collections items are specified
} else {
    collections_items <- input$collections_items
}

# Load study area
study_area <- st_read(input$study_area_polygon) %>% st_transform("EPSG:4326")

# Define bounding box
bbox <- sf::st_bbox(c(xmin = input$bbox[1], ymin = input$bbox[2],
            xmax = input$bbox[3], ymax = input$bbox[4]), crs=st_crs(4326)) 

# Load cube using the loadFromStacFun
raster_layers <- list()
stats_list <- list()
for(i in 1:length(collections_items)){

  ci <- strsplit(collections_items[i], split = "|", fixed=TRUE)[[1]] # split into collection and layers

  dat_cube <- load_cube(stac_path=input$stac_url, collections=ci[1], ids=ci[2], bbox=bbox,
                           srs.cube = "EPSG:4326", layers=NULL, variable=NULL,
                            t0 = NULL,   t1 = NULL, temporal.res = "P1D", aggregation = "mean",  resampling = "near")
raster_layers[[i]]=dat_cube # add to a list of raster layers
names(raster_layers)[i] <- ci[2]

if(input$summary_statistic == "mean"){
stats_each <- gdalcubes::extract_geom(cube=dat_cube, sf=study_area, FUN=mean, reduce_time=TRUE)
} else if(input$summary_statistic == "median"){
  stats_each <- gdalcubes::extract_geom(cube=dat_cube, sf=study_area, FUN=median, reduce_time=TRUE)
} else {
  stats_each <- gdalcubes::extract_geom(cube=dat_cube, sf=study_area, FUN=mode, reduce_time=TRUE)}

stats_each$name <- ci[2]
stats_list[[i]] = as.data.frame(stats_each)
}

stats <- bind_rows(stats_list)
stats <- stats[,c(3,2)]
names(stats)[names(stats) == 'data']<-input$summary_statistic

stats_path <- file.path(outputFolder, "stats.csv")
write.csv(stats, stats_path, row.names=F)

layer_paths<-c()
# need to rename these to be more descriptive
output_raster_layers <- file.path(outputFolder)

for (i in 1:length(raster_layers)) {
  ff <- tempfile(pattern = paste0(names(raster_layers[i]),'_'))
  out<-gdalcubes::write_tif(raster_layers[i][[1]], dir = output_raster_layers, prefix=basename(ff), creation_options = list("COMPRESS" = "DEFLATE"), COG=TRUE, write_json_descr=TRUE)
  fp <- paste0(out[1])
  layer_paths <- cbind(layer_paths,fp)
}


output <- list("stats" = stats_path, "rasters" = layer_paths)
}, error = function(e) { list(error = conditionMessage(e)) })

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))


