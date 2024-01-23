#### Load required packages - libraries to run the script ####

# Install necessary libraries - packages  
packagesPrev<- installed.packages()[,"Package"] # Check and get a list of installed packages in this machine and R version
packagesNeed<- c("terra", "rjson", "raster", "stars", "dplyr", "stacatalogue", "lubridate", "stringr", "remotes", "RCurl", "gdalcubes") # Define the list of required packages to run the script
lapply(packagesNeed, function(x) {   if ( ! x %in% packagesPrev ) { install.packages(x, force=T)}    }) # Check and install required packages that are not previously installed

# Load libraries
packagesList<-list("magrittr", "terra") # Explicitly list the required packages throughout the entire routine. Explicitly listing the required packages throughout the routine ensures that only the necessary packages are listed. Unlike 'packagesNeed', this list includes packages with functions that cannot be directly called using the '::' syntax. By using '::', specific functions or objects from a package can be accessed directly without loading the entire package. Loading an entire package involves loading all the functions and objects 
lapply(packagesList, library, character.only = TRUE)  # Load libraries - packages  

Sys.getenv("SCRIPT_LOCATION")
outputFolder<- {x<- this.path::this.path();  file_prev<-  paste0(gsub("/scripts.*", "/output", x), gsub("^.*/scripts", "", x)  ); options<- tools::file_path_sans_ext(file_prev) %>% {c(., paste0(., ".R"), paste0(., "_R"))}; folder_out<- options %>% {.[file.exists(.)]} %>% {.[which.max(sapply(., function(info) file.info(info)$mtime))]}; folder_final<- list.files(folder_out, full.names = T) %>% {.[which.max(sapply(., function(info) file.info(info)$mtime))]} }

input <- rjson::fromJSON(file=file.path(outputFolder, "input.json")) # Load input file

input<- lapply(input, function(x) if( grepl("/", x) ){
  sub("/output/.*", "/output", outputFolder) %>% dirname() %>%  file.path(x) %>% {gsub("//+", "/", .)}  }else{x} ) # adjust input 1


## Organizar coleccion

# Case 1: we create an extent from a set of observations
box_4326 <-  sf::st_read("C:/Users/LENOVO/Documents/Caldas.shp") %>% sf::st_transform(4326) %>% sf::st_bbox()


RSTACQuery <- rstac::stac("http://io.biodiversite-quebec.ca/stac/")

STACItemCollection <- rstac::stac_search(q= RSTACQuery, collections = "chelsa-clim" , bbox = box_4326) %>% rstac::get_request()

assets<- unlist(lapply(STACItemCollection$features,function(y){names(y$assets)})) %>% unique()

image_collection <- gdalcubes::stac_image_collection(STACItemCollection$features, asset_names = assets )

t0<- gdalcubes::extent(image_collection)$t0
t1<- gdalcubes::extent(image_collection)$t1

# Establecer cube view
cube_collection<- gdalcubes::cube_view(srs = crs_polygon,  extent = list(t0 = t0, t1 = t1,
                                                                         left = box_rasterbase[1], right = box_rasterbase[3],
                                                                         top = box_rasterbase[4], bottom = box_rasterbase[2]),
                                       nx = dim_rasterbase[2], ny = dim_rasterbase[1], dt = "P1Y",aggregation = "near", resampling = "first",
                                       keep.asp= T)























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
if(mask==''){
  mask=NULL
}


predictors=list()
nc_names=c()

for (coll_it in collections_items){
    ci<-strsplit(coll_it, split = "|", fixed=TRUE)[[1]]

    cube_args_c <- append(cube_args, list(collections=ci[1],
                                          srs.cube = proj, 
                                          bbox = bbox,
                                          layers=NULL,
                                          variable = NULL,
                                          ids=ci[2]))
    print(cube_args_c)
    pred <- do.call(stacatalogue::load_cube, cube_args_c)

     if(!is.null(mask)) {
        pred <- gdalcubes::filter_geom(pred, sf::st_geometry(mask))
      }
      nc_names <- cbind(nc_names,names(pred))
      if(names(pred)=='data'){
        pred <- rename_bands(pred, data=ci[2])
      }
     print(pred)

     predictors[[ci[2]]]=pred
}
  print(names(predictors))

output_predictors <- file.path(outputFolder)

layer_paths<-c()
for (i in 1:length(predictors)) {
  ff <- tempfile(pattern = paste0(names(predictors[i][[1]]),'_'))
  out<-gdalcubes::write_tif(predictors[i][[1]], dir = output_predictors, prefix=basename(ff),creation_options = list("COMPRESS" = "DEFLATE"), COG=TRUE, write_json_descr=TRUE)
  fp <- paste0(out[1])
  layer_paths <- cbind(layer_paths,fp)
  if(!is.null(weight_matrix)) {
    weight_matrix <- sub(stac_collections_items[i],fp[1], weight_matrix, fixed=TRUE)
  }
}

 if(is.null(weight_matrix)) { #Temporary fix
  weight_matrix=''
 }

output <- list("rasters" = layer_paths,"weight_matrix_with_layers" = weight_matrix)
jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))