library(gdalcubes)
library(sf)

input <- biab_inputs()

bbox_input <- input$bbox_crs$bbox

crs_input <- paste0(input$bbox_crs$CRS$authority,":",input$bbox_crs$CRS$code)
print(crs_input)
bbox <- st_bbox(c(xmin =bbox_input[1], ymin = bbox_input[2], 
        xmax = bbox_input[3], ymax = bbox_input[4]), crs = st_crs(crs_input))


gdalcubes::gdalcubes_options(parallel = T)
## Create function

## Load Cube
stac_path="https://stac.geobon.org/"
collections = 'chelsa-clim-proj'         
bbox = bbox
limit = 5000
srs.cube = crs_input
rcp = input$rcp #ssp126, ssp370, ssp585
time.span =input$time_span #"2011-2040", 2041-2070 or 2071-2100
variable = input$variable
spatial.res = input$spatial_res# in meters
temporal.res = "P1Y"  
aggregation = input$aggregation
resampling = "bilinear"
  

  # t0 param
  if (time.span == "2011-2040") {
    t0 <- "2011-01-01"
  }
  
  if (time.span == "2041-2070") {
    t0 <- "2041-01-01"
  }
  
  if (time.span == "2071-2100") {
    t0 <- "2071-01-01"
  }
  
  datetime <-
    format(lubridate::as_datetime(t0), "%Y-%m-%dT%H:%M:%SZ")
  s <- rstac::stac(stac_path, force_version=TRUE)
  
    left <- bbox$xmin
    right <- bbox$xmax
    bottom <- bbox$ymin
    top <- bbox$ymax
    
    if (left > right) {
      stop("left and right seem reversed")
    }
    if (bottom > top) {
      stop("bottom and top seem reversed")
    }
    
    # Create the bbox (WGS84 projection)

    bbox.wgs84 <- bbox %>% sf::st_bbox(crs = srs.cube) %>% 
      sf::st_as_sfc() %>% sf::st_transform(crs = "EPSG:4326") %>% 
      sf::st_bbox()
 
  
  it_obj <- s %>%
    rstac::stac_search(bbox = bbox.wgs84,
                       collections = collections,
                       datetime = datetime,
                       limit = limit) %>%
    rstac::get_request() # bbox in decimal lon/lat
  
  # If no layers is selected, get all the layers by default
    layers <- unlist(lapply(it_obj$features, function(x) {
      names(x$assets)
    }))
  
  # Force each dataset to have the data role. Fix 08/2023
    for (i in 1:length(it_obj$features)){
        it_obj$features[[i]]$assets[[1]]$roles<-'data'
    }
    
  
  #
  # Creates an image collection
  if (!is.null(variable)) {
    st <- gdalcubes::stac_image_collection(
      it_obj$features,
      asset_names = layers,
      property_filter = function(x) {
        x[["variable"]] %in% variable & x[["rcp"]] == rcp
      }
    )
  } else {
    st <- gdalcubes::stac_image_collection(
      it_obj$features,
      asset_names = layers,
      property_filter = function(x) {
        x[["rcp"]] == rcp
      }
    )
  }
  
  
  # if layers = NULL, load all the layers
  v <- gdalcubes::cube_view(
    srs = srs.cube,
    extent = list(
      t0 = t0,
      t1 = t0,
      left = left,
      right = right,
      top = top,
      bottom = bottom
    ),
    dx = spatial.res,
    dy = spatial.res,
    dt = temporal.res,
    aggregation = aggregation,
    resampling = resampling
  )
  cube_future <- gdalcubes::raster_cube(st, v)

print(cube_future)
#cube_future <- gdalcubes::as_stars(cube_future)
#cube_future <- rast(cube_future)
print(class(cube_future))
print(cube_future[1])
print(names(cube_future))
#  layer_paths<-c()
#  for (i in 1:length(cube_future)) {
#    ff <- tempfile(pattern = paste0(names(cube_future[i]),'_'))
#    out<-gdalcubes::write_tif(cube_future[i], dir = file.path(outputFolder), prefix=basename(ff),creation_options = list("COMPRESS" = "DEFLATE"), COG=TRUE, write_json_descr=TRUE)
#    fp <- paste0(out[1])
#    layer_paths <- cbind(layer_paths,fp)
#  }


 out<-gdalcubes::write_tif(cube_future, dir = file.path(outputFolder), prefix = "future_climate", creation_options = list("COMPRESS" = "DEFLATE"), 
      COG=TRUE, write_json_descr=TRUE)

# layer_paths <- c()
# for(i in 1:length(names(cube_future))){
# layer_paths[i] <- paste0(outputFolder, "/", names(cube_future[i]), ".tif")
#  terra::writeRaster(x = cube_future[i],
#                       layer_paths[i],
#                       filetype='COG',
#                      options=c("COMPRESS=DEFLATE"),
#                      overwrite = TRUE)
# }

biab_output("future_climate", file.path(out[1]))