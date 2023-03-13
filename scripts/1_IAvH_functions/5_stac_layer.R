### función stac_layer

# Cargar librerias
packages_list<-list("magrittr")
invisible({lapply(packages_list, library, character.only = TRUE)})

# Organizar directorios
Sys.setenv(OUTPUT_FOLDER = "/path/to/output/folder")


# Cargar archivos de entrada
input <- rjson::fromJSON(file=file.path(outputFolder, "input.json"))

folder_name<- tools::file_path_sans_ext(input$folder_workflow)
folder_results<- paste0(dirname(dirname(dirname(outputFolder))), "/", input$folder_workflow)
setwd(folder_results)



# Cargar stac_colections_layers
stac_colections_layers_file<- paste0(input$collection_layers, ".RData")

if(file.exists(folder_results)){ setwd(folder_results); 
  if(file.exists(stac_colections_layers_file)){
    load(stac_colections_layers_file); 
  } else { stop("No se encuentra el archivo dir_stac especificado") 
  } } else{ stop("No se encuentra el folder_workflow especificado") }

if(!exists("stac_colections_layers")){ stop("Error al cargar archivo dir_stac especificado") } 






## Función core área de estudio, y estimación de metricas área de estudio

## Estimar metricas ÃƒÂ¡rea de estudio
stac_layer<- function(dir_polygon= NULL, res= 1000, colections_layers= NULL){
  
  suppressMessages({
    
    
    # organizar data
    vector_polygon <- terra::vect(dir_polygon) %>% terra::as.polygons()
    crs_polygon<- crs(vector_polygon)
    wkt_polygon <- geom(vector_polygon, wkt=TRUE) %>% {  paste0( "MULTIPOLYGON (",paste(gsub("POLYGON ", "", .), collapse=  ", "),")")  }
    
    
    box_polygon<-  sf::st_bbox(vector_polygon)
    
    
    # estimar metricas por colecciÃƒÂ³n
    list_colections<- lapply(names(colections_layers), function(y) { print(y)
      
      x<- colections_layers[[y]]

      # cubo
      v = gdalcubes::cube_view(srs = crs_polygon,  extent = list(t0 = gdalcubes::extent(x)$t0, t1 = gdalcubes::extent(x)$t1,
                                                      left = box_polygon[1], right = box_polygon[3],
                                                      top = box_polygon[4], bottom = box_polygon[2]),
                    dx = res, dy = res, dt = "P1Y", aggregation = "first", resampling = "first", keep.asp= F)
      
      cube <- raster_cube(x, v)
      cube_mask<- filter_geom(cube, geom= wkt_polygon, srs = crs_polygon )
      cube_stars <- stars::st_as_stars(cube_mask) %>% rast()
      
      
      collection_rast<- lapply(cube_stars, function(x) { if(any( is.na(summary(raster::raster(x))) )){NULL}else{x} } ) %>%
        {Filter(function(x) !is.null(x), .)} %>% {setNames(., unlist(sapply(., function(x) names(x))) )}
      
      list_rast<- lapply(collection_rast, function(x) {
        

        # estimar area (probar freqDT - rasterDT)
        areas<- rasterDT::freqDT(raster::raster(x)) %>% dplyr::mutate(area_ha = freq*(res^2)  / 10000) %>%
          dplyr::mutate(prop= area_ha / sum(.$area_ha)) 
        
        
        list(name= names(x), layer= x, metadata= areas) }
      )
      
    }) %>% setNames(names(colections_layers))
    
  })
}


stac_colections_layers<- load_layer_collection(collection_object= colections_stac$output,
                                               collection_layers = collection_interest
)




layers_final<- stac_layer(
  dir_polygon= "D:/IAvH 2022/STAC/biab-2.0/scripts/IAvH_inputs/Amazonas.shp", 
  res=1000,
  colections_layers= stac_colections_layers
)



output_name<- "layers_final"


### Guardar resultado en formato rds
setwd(folder_results)
output_RData = file.path(folder_results, paste0(output_name, ".RData"))
save(layers_final, file= output_RData )

layers_tif<- unlist(layers_final, recursive = F) %>%    purrr::map("layer")

setwd(folder_results)
dir.create("maps"); setwd("maps")
lapply(names(layers_tif), function(x){  writeRaster(layers_tif[[x]], paste0(x, ".tif"), overwrite=T)})

folder_layers<- paste0(folder_results, "/maps")


## Guardar resultado en formato txt
setwd(folder_results)
output_txt = file.path(folder_results, paste0(output_name, ".txt"))
my_output <- layers_final %>% lapply( function(x) {gsub(",", ";", x)} ) %>% {list(repository_collections=.)}
sink(output_txt); print(stac_colections_layers); sink()


## Borrar resultados cache
different_files<- list.files(folder_results) %>% {.[!grepl("repository_stac|repository_collections|colections_stac|stac_colections_layers",.)]}
sapply(different_files, function(x) file.remove(x))


## Inprimir resultado - Interfaz Logs
layers_final






## Imprimir resultado - Formao json
output <- list("layers_final_txt" = output_txt, "layers_final_RData" = output_RData, "Folder_maps"= folder_layers)
jsonData <- rjson::toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))