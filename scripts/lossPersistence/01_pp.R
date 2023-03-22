### funci?n check_collections

# Cargar librerias
packages_list<-list("magrittr", "terra", "raster")
invisible(   lapply(packages_list, library, character.only = TRUE)   )

# Organizar directorios
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1]

# Cargar archivos de entrada
input <- rjson::fromJSON(file=file.path(outputFolder, "input.json"))

dir_wkt<- input$dir_wkt_polygon
dir_colection<- input$dir_colection


epsg_polygon<- input$epsg_polygon
resolution<- input$resolution
folder_output<- input$folder_output

# ajustar resolucion
resolution<- raster::raster(raster::extent(seq(4)),crs= "+init=epsg:3395", res= input$resolution) %>% projectRaster( crs = sf::st_crs(epsg_polygon)$proj4string ) %>% 
  raster::res()

# Definir área de estudio
vector_polygon<- terra::vect(dir_wkt, crs= sf::st_crs(epsg_polygon)$proj4string ) 
crs_polygon<- terra::crs(vector_polygon)
box_polygon<-  sf::st_bbox(vector_polygon)

# Cargar coleccion
layers <- list.files(dir_colection, "\\.tif$", recursive = TRUE, full.names = TRUE)
json_colleciton_file <- list.files(dir_colection, "\\.json$", recursive = TRUE, full.names = TRUE)
meadata_collecion_file <- list.files(dir_colection, "\\.csv$", recursive = TRUE, full.names = TRUE)
metadata<- read.csv(meadata_collecion_file)

# Especificar carpea donmde guardar resultados
folder_results<- paste0(dirname(dirname(dirname(outputFolder))), "/", folder_output)
dir.create(folder_results)

# Alinear con colecci?on
stac_collection<- gdalcubes::create_image_collection(files= layers, format= json_colleciton_file) 

# Cargar cubo
cube_collection<- gdalcubes::cube_view(srs = crs_polygon,  extent = list(t0 = gdalcubes::extent(stac_collection)$t0, t1 = gdalcubes::extent(stac_collection)$t1,
                                                                         left = box_polygon[1], right = box_polygon[3],
                                                                         top = box_polygon[4], bottom = box_polygon[2]),
                                       dx = resolution[1], dy = resolution[2], dt = "P1Y", aggregation = "first", resampling = "first", keep.asp= F)

cube <- gdalcubes::raster_cube(stac_collection, cube_collection)

# Cortar cubo por area de estudio
cube_mask<- gdalcubes::filter_geom(cube, geom= dir_wkt, srs = crs_polygon )

# Convertir cubo a raster
cube_stars <- stars::st_as_stars(cube_mask) %>% terra::rast() %>% setNames(names(cube_mask))

collection_rast<- lapply(cube_stars, function(x) { if(any( is.na(summary(raster::raster(x))) )){NULL}else{x} } ) %>%
  {Filter(function(x) !is.null(x), .)} %>% {setNames(., unlist(sapply(., function(x) names(x))) )} %>% terra::rast()

# estimar metricas de area
data_sum<- terra::freq(cube_stars, usenames=T) %>% dplyr::mutate(area= (count*sqrt(prod(resolution)))/10000  ) %>% dplyr::select(-count) %>%
  dplyr::rename(collection= layer) %>% dplyr::mutate(layer= sapply(.$collection, function(x) stringr::str_split(x, "_B*time")[[1]][1]) ) %>%
  {list(metadata,.)} %>% plyr::join_all() %>% dplyr::group_by(layer)  %>% dplyr::mutate(percentaje=  area/sum(area) )

data_sum$period<-  unlist(strsplit(data_sum$layer, "_") %>% sapply(function(x) paste(x[c(2:3)], collapse = "-")), recursive = T)

# partir y guardar raster acorde a los valores
setwd(folder_results)
saveraster<- lapply( seq(nrow(data_sum)), function(i) {
  
  x<- data_sum[i, ]
  
  raster_val<- collection_rast[x$layer]
  raster_val[!raster_val %in% x$value]= NA
  raster_val[raster_val %in% x$value]= 1
  
  terra::writeRaster(raster_val, paste0( paste(c("forestLP", x$period, x$key), collapse = "-") ,  ".tif"), overwrite=T)
  
} )



# Organizar tabla de salida
data_sum2<- data_sum %>% as.data.frame() %>%  dplyr::rowwise() %>% dplyr::select(- c("collection")) %>% 
  dplyr::mutate(layer= paste(c("forestLP", period, key), collapse = "-")) %>% as.data.frame() %>% 
  dplyr::relocate(c("layer"), .before = "value") %>% 
  dplyr::relocate(c("key", "period"), .before = "area")




# guardar tabla resumen
dir_table<- paste0(folder_results, "/data_summ.csv")
write.csv(data_sum2, dir_table, row.names = F)


# Imprimir resultado en logs
print(data_sum)

## Imprimir resultado - Formao json
output <- list("folder_output" = folder_results, "table_pp"= dir_table)
jsonData <- rjson::toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))