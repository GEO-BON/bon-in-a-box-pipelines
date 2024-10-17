## This is a script to load BII layers from the STAC catalog and calculate zonal statistics for a polygon (country or region) of interest, and summarise changes
## Modified from Zonal Statistics 

library("rjson")
library("dplyr")
library("gdalcubes")
library("sf")
library("ggplot2")
library("terra")
sf_use_s2(FALSE)

# load from STAC function to load data cube
source(paste(Sys.getenv("SCRIPT_LOCATION"), "/data/loadFromStacFun.R", sep = "/"))

input <- fromJSON(file=file.path(outputFolder, "input.json"))

output<- tryCatch({
# # Collections items
# if (length(input$collections_items) == 0) {
#     stop('Please specify collections_items') # if no collections items are specified
# } else {
#     collections_items <- input$collections_items
# }
collections_items <- c("bii_nhm|bii_nhm_10km_2000", 
    "bii_nhm|bii_nhm_10km_2005", "bii_nhm|bii_nhm_10km_2010", "bii_nhm|bii_nhm_10km_2015", "bii_nhm|bii_nhm_10km_2020")

# Load study area
study_area <- st_read(input$study_area_polygon) %>% st_transform("EPSG:4326")

# Define bounding box
bbox <- sf::st_bbox(c(xmin = input$bbox[1], ymin = input$bbox[2],
            xmax = input$bbox[3], ymax = input$bbox[4]), crs=st_crs(4326)) 
print(bbox)
# Load cube using the loadFromStacFun
raster_layers <- c()
stats_list <- list()
for(i in 1:length(collections_items)){

  ci <- strsplit(collections_items[i], split = "|", fixed=TRUE)[[1]] # split into collection and layers

  dat_cube <- load_cube(stac_path=input$stac_url, collections=ci[1], ids=ci[2], bbox=bbox,
                           srs.cube = "EPSG:4326", layers=NULL, variable=NULL, spatial.res=0.08,
                            t0 = NULL, t1 = NULL, temporal.res = "P1D", aggregation = "mean",  resampling = "near") # load cube from loacFromStacFun

raster_layers[[i]] <- dat_cube # add to a list of raster layers
names(raster_layers)[i] <- ci[2]

if(input$summary_statistic == "Mean"){
stats_each <- gdalcubes::extract_geom(cube=dat_cube, sf=study_area, FUN=mean, reduce_time=TRUE)
} else if(input$summary_statistic == "Median"){
  stats_each <- gdalcubes::extract_geom(cube=dat_cube, sf=study_area, FUN=median, reduce_time=TRUE)
} else {
  stats_each <- gdalcubes::extract_geom(cube=dat_cube, sf=study_area, FUN=mode, reduce_time=TRUE)}
print(stats_each)
#stats_each$name <- ci[2]
#stats_each <- as.data.frame(stats_each)
stats_layer <- data.frame(name=ci[2], statistic=stats_each[1,2])
stats_list[[i]] <- stats_layer
}

stats <- bind_rows(stats_list)
stats$year <- c(2000, 2005, 2010, 2015, 2020)

# make time series plot of BII
statistic_choice <- input$summary_statistic

ts_plot <- ggplot(stats, aes(x=year, y=statistic)) +
    geom_point(color="red")+
    geom_line(color="red")+
    labs(x="Year", y=paste0(statistic_choice, " BII (%)"))+
    theme_classic()

stats_path <- file.path(outputFolder, "stats.csv")
write.csv(stats, stats_path, row.names=F)

ts_plot_path <- file.path(outputFolder, "ts_plot.png")
ggsave(ts_plot_path, ts_plot)

layer_paths<-c()
# need to rename these to be more descriptive
output_raster_layers <- file.path(outputFolder)

for (i in 1:length(raster_layers)) {
  ff <- tempfile(pattern = paste0(names(raster_layers[i]),'_'))
  out<-gdalcubes::write_tif(raster_layers[i][[1]], dir = output_raster_layers, prefix=basename(ff), creation_options = list("COMPRESS" = "DEFLATE"), COG=TRUE, write_json_descr=TRUE)
  fp <- paste0(out[1])
  layer_paths <- cbind(layer_paths,fp)
}

output <- list("stats" = stats_path, "rasters" = layer_paths, "ts_plot" = ts_plot_path)
}, error = function(e) { list(error = conditionMessage(e)) })

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))


