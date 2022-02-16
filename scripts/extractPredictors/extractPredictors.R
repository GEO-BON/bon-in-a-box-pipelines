## Environment variables available
# Script location can be used to access other scripts
print(Sys.getenv("SCRIPT_LOCATION"))

## Install required packages
packages <- c("gdalcubes", "rjson", "raster", "dplyr", "rstac", "tibble", "sp", "sf",
  "curl")


new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

## Load required packages
library("gdalcubes")
library("rjson")
library("raster")
library("dplyr")
library("rstac")
library("tibble")
library("sp")
library("sf")
library("curl")
option(curl_interrupt = F)

## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")


input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)


# Load functions

projectCoords <- function(xy, proj.i = "+proj=longlat +datum=WGS84", proj.y) {
  sp::coordinates(xy) <- c("decimalLongitude", "decimalLatitude")
  proj4string(xy) <- CRS(proj.i)
  xy <- spTransform(xy, CRS(proj.y)) 
  xy
}

findBox <- function(xy, buffer = 0, proj.new = NULL) {
  if (class(xy) != "SpatialPoints") {
    sp::coordinates(xy) <- colnames(xy)
    proj4string(xy) <- CRS(proj)
  }
  studyExtent <-  st_buffer(st_as_sfc(st_bbox(xy)), dist =  buffer) 
  
  if (!is.null(proj.new) ) {
    studyExtent <- studyExtent  %>% 
      st_transform(crs = CRS(proj.new))
  }

  bbox <- c(st_bbox(studyExtent)$xmin, st_bbox(studyExtent)$xmax, 
            st_bbox(studyExtent)$ymin, st_bbox(studyExtent)$ymax)
  bbox
}

loadCube <- function(stac_path = "http://io.biodiversite-quebec.ca/stac/",
                     limit = 5000, 
                     collections = c('chelsa-clim'), 
                     use.obs = T,
                     decimal.coords,
                     buffer.box = 0,
                     bbox = NULL, layers = NULL,
                     srs = "EPSG:32198",  t0 = "1981-01-01", t1 = "1981-01-31", 
                     left = -2009488, right = 1401061,  bottom = -715776, top = 2597757, spatial_res = 2000, 
                     temporal_res  = "P1Y", aggregation = "mean",
                     resampling = "near") {
  
  s <- stac(stac_path)
  
  if (use.obs) {
    proj.pts <- projectCoords(decimal.coords, proj.i = "+proj=longlat +datum=WGS84", proj.y = srs)
    bbox <- findBox(proj.pts, buffer = buffer.box, proj.new ="+proj=longlat +datum=WGS84")
    bbox.proj <- findBox(proj.pts, buffer = buffer.box)
    left <- bbox.proj[1]
    right <- bbox.proj[2]
    bottom <- bbox.proj[3]
    top <- bbox.proj[4]

  }

  it_obj <- s |>
    stac_search(bbox = bbox, collections = collections, limit = 5000) |> get_request() # bbox in decimal lon/lat 
  
  if (is.null(layers)) {
    layers <-unlist(lapply(it_obj$features,function(x){names(x$assets)}))
    
  }
  st <-stac_image_collection(it_obj$features, asset_names = layers) #if layers = NULL, load all the layers
  
  v <- cube_view(srs = srs,  extent = list(t0 = t0, t1 = t1,
                                          left = left, right = right,  top = top, bottom = bottom),
                dx = spatial_res, dy = spatial_res, dt = temporal_res, aggregation = aggregation, resampling = resampling)
  
  gdalcubes_options(threads = 4)
 
   cube <- raster_cube(st, v) 
   # cube <-   raster_cube(st, v, chunking = c(1, 500, 500))
   return(cube)
}


obs <- read.table(file = input$obs, sep = '\t', header = TRUE) 

decimal.coords <- dplyr::select(obs, decimalLongitude, decimalLatitude)
proj.pts <- projectCoords(decimal.coords, proj.i = "+proj=longlat +datum=WGS84", proj.y = input$srs)

cube <- 
  loadCube(stac_path = input$stac_path,
           limit = input$limit, 
           collections = c(input$collections), 
           use.obs = T,
           decimal.coords = decimal.coords,
           buffer.box = input$buffer.box,
           layers= input$layers,
           srs = input$srs,
           t0 = input$t0,
           t1 = input$t1,
           spatial_res = input$spatial_res) 

obs <- bind_cols(obs, 
                 setNames(data.frame(proj.pts), c("lon", "lat"))) 

value.points <- query_points(cube, obs$lon, obs$lat, pt = rep(as.Date(input$t0), length(obs$lon)), srs(cube))



obs.values <- file.path(outputFolder, "obs_values.tsv")
write.table(obs, obs.values,
             append = F, row.names = F, col.names = T, sep = "\t")


  output <- list(
                  "obs.values" = obs.values
                  ) 
  jsonData <- toJSON(output, indent=2)
  write(jsonData, file.path(outputFolder,"output.json"))
  
