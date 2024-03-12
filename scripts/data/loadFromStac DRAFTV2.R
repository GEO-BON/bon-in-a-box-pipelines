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

# Force each dataset to have the data role. Fix 08/2023
for (i in 1:length(it_obj$features)){
  it_obj$features[[i]]$assets[[1]]$roles<-'data'
}


if (!is.null(ids)) {
  feats<-it_obj$features[lapply(it_obj$features,function(f){f$id %in% ids})==TRUE]
  print(feats[ids])
}else{
  feats<-it_obj$features
}

st <- gdalcubes::stac_image_collection(feats,
                                       asset_names = ids)