collections_items<- c("chelsa-clim|bio1", "chelsa-clim|bio2")
coll_it<- collections_items[[1]]
ci<-strsplit(coll_it, split = "|", fixed=TRUE)[[1]]




stac_path = "https://io.biodiversite-quebec.ca/stac/";
limit = NULL;
collections = c("chelsa-clim");
layers = NULL;
variable = NULL;
ids = NULL;
mask = NULL;
srs.cube = "EPSG:6623";
spatial.res = NULL;
temporal.res = "P1Y";
aggregation = "mean";
resampling = "near";
stac_path = input$stac_url;
limit = 5000;
t0 = NULL;
t1 = NULL;
spatial.res = input$spatial_res; # in meters
temporal.res = "P1D";
aggregation = "mean";
resampling = "near";
collections=ci[1];
srs.cube = proj; 
bbox = bbox;
layers=NULL;
variable = NULL;
ids=ci[2]



##############################

bbox <- sf::st_bbox(c(xmin = -2316297, ymin = -1971146,
                      xmax = 1015207, ymax = 1511916), crs = sf::st_crs("EPSG:6623")) 


s <- rstac::stac(stac_path)
if (!inherits(bbox, "bbox"))
  stop("The bbox is not a bbox object.")
left <- bbox$xmin
right <- bbox$xmax
bottom <- bbox$ymin
top <- bbox$ymax

bbox.wgs84 <- bbox %>% sf::st_bbox(crs = srs.cube) %>% sf::st_as_sfc() %>%
  sf::st_transform(crs = "EPSG:4326") %>% sf::st_bbox()


it_obj_tmp <- s %>% rstac::stac_search(bbox = bbox.wgs84,
                                       collections = collections,
                                       limit = limit) %>% rstac::get_request()
datetime <- it_obj_tmp$features[[1]]$properties$datetime
t0 <- datetime
t1 <- datetime

t1 <- t0




it_obj <-
  s %>% rstac::stac_search(
    bbox = bbox.wgs84,
    collections = collections,
    datetime = datetime,
    limit = limit
  ) %>% rstac::get_request()


for (i in 1:length(it_obj$features)){
  it_obj$features[[i]]$assets[[1]]$roles<-'data'
}


st <- gdalcubes::stac_image_collection(feats,
                                       asset_names = ids)
