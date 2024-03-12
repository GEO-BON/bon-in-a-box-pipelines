


# Case 1: we create an extent from a set of observations
bbox <- sf::st_bbox(c(xmin = input$bbox[1], ymin = input$bbox[2],
                      xmax = input$bbox[3], ymax = input$bbox[4]), crs = sf::st_crs(input$proj)) 

print(length(input$collections_items))

if (length(input$collections_items)==0) {
  if (length(input$weight_matrix_with_ids) == 0) {
    stop('Please specify collections_items')
  } else {
    weight_matrix<-input$weight_matrix_with_ids
    stac_collections_items <- unlist(lapply((str_split(weight_matrix,'\n',simplify=T) |> str_split(','))[-1],function(l){l[1]}))
    stac_collections_items <- stac_collections_items[startsWith(stac_collections_items,'GBSTAC')]
    collections_items <- gsub('GBSTAC|','',stac_collections_items, fixed=TRUE)
  }
} else {
  weight_matrix=NULL
  collections_items <- input$collections_items
}

cube_args = list(stac_path = input$stac_url,
                 limit = 5000,
                 t0 = NULL,
                 t1 = NULL,
                 spatial.res = input$spatial_res, # in meters
                 temporal.res = "P1D",
                 aggregation = "mean",
                 resampling = "near")

subset_layers = input$layers
proj = input$proj
as_list = F

mask=input$mask
predictors=list()
nc_names=c()




coll_it<- collections_items[[1]]

ci<-strsplit(coll_it, split = "|", fixed=TRUE)[[1]]




test_cube<- load_cube(
  stac_path = input$stac_url,
  limit = 5000,
  t0 = NULL,
  t1 = NULL,
  spatial.res = input$spatial_res, # in meters
  temporal.res = "P1D",
  aggregation = "mean",
  resampling = "near",
  collections=ci[1],
  srs.cube = proj, 
  bbox = bbox,
  layers=NULL,
  variable = NULL,
  ids=ci[2])





