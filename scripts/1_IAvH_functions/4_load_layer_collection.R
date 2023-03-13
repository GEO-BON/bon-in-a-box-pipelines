### función load_layer_collections

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


# Cargar collection_object
collection_object_file<- paste0(input$collection_object, ".RData")

if(file.exists(folder_results)){ setwd(folder_results); 
  if(file.exists(collection_object_file)){
    load(collection_object_file); 
  } else { stop("No se encuentra el archivo dir_stac especificado") 
  } } else{ stop("No se encuentra el folder_workflow especificado") }

if(!exists("collection_object_file")){ stop("Error al cargar archivo dir_stac especificado") } 

# Organizar collecion solicitudes
collection_layers<- purrr::map(colections_stac$output,  "layers_collection") 
collection_layers_index<- gsub("colections_stac", "collection_layers", input$collection_layers)
collection_interest<- eval(parse(text= collection_layers_index )) %>% setNames(names(collection_layers))



## funcion recopilar coleccion deseada
load_layer_collection <- function(collection_object= NULL, collection_layers= NULL){
  
  if(length(collection_layers)>0){
    
    collection_cube<- lapply( names(collection_layers), function(h){ 
      
      col_data<- collection_object[[h]]$collection
      col_layers<- if( length(collection_layers[[h]]) <1 ){unlist(lapply(col_data$features,function(y){names(y$assets)}))}else{collection_layers[[h]]}
      coll <- gdalcubes::stac_image_collection(col_data$features, asset_names =   col_layers , skip_image_metadata= F)
      
    }
    ) %>% setNames(names(collection_layers))
    collection_cube
    
  } else { print("Las colecciones listadas no coinciden con el objeto de colecciÃ³n definida. Por favor revisar")}
  
}


### Ejecutar funcion
stac_colections_layers<- load_layer_collection(collection_object= colections_stac$output,
                                               collection_layers = collection_interest
)





output_name<- "stac_colections_layers"

### Guardar resultado en formato rds
setwd(folder_results)
output_RData = file.path(folder_results, paste0(output_name, ".RData"))
save(repository_stac, repository_collections, colections_stac, stac_colections_layers, load_layer_collection, colections_stac, collection_layers, collection_interest, file= output_RData )

## Guardar resultado en formato txt
output_txt = file.path(folder_results, paste0(output_name, ".txt"))
my_output <- repository_collections %>% lapply( function(x) {gsub(",", ";", x)} ) %>% {list(repository_collections=.)}
sink(output_txt); print(stac_colections_layers); sink()


## Borrar resultados cache
different_files<- list.files(folder_results) %>% {.[!grepl("repository_stac|repository_collections|colections_stac|stac_colections_layers",.)]}
sapply(different_files, function(x) file.remove(x))


## Inprimir resultado - Interfaz Logs
stac_colections_layers






## Imprimir resultado - Formao json
output <- list("stac_colections_layers_txt" = output_txt, "stac_colections_layers_RData" = output_RData)
jsonData <- rjson::toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))



