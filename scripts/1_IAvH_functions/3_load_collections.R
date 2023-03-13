### función load_collections

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

# Cargar dir_stac
dir_stac_file<- paste0(input$dir_stac, ".RData")

if(file.exists(folder_results)){ setwd(folder_results); 
  if(file.exists(dir_stac_file)){
    load(dir_stac_file); 
  } else { stop("No se encuentra el archivo dir_stac especificado") 
  } } else{ stop("No se encuentra el folder_workflow especificado") }

if(!exists("repository_stac")){ stop("Error al cargar archivo dir_stac especificado") } 


# Cargar name_collections
dir_collection<- input$name_collections

dir_collection_names<- if(grepl("\\]",dir_collection)){
  
  file_collection<- strsplit(dir_collection, "\\[")[[1]][1] %>% paste0(".RData")
  index_collection<- strsplit(dir_collection, "\\[")[[1]][2] %>% {gsub("\\]", "", .)} %>% sapply(function(x) eval(parse(text=x))) %>%
    unlist() %>% as.numeric()
    
  if(file.exists(file_collection)){
    load(file_collection); 
  } else { stop("No se encuentra el archivo name_collections especificado") 
  }
  
 repository_collections$output[index_collection] %>% na.omit() %>% as.character()
  
} else { dir_collection}

if(length(dir_collection_names)<1){ stop("Error en los indices especificados") } 





### Generar función
load_collections<- function(dir_stac= NULL, collection= NULL){
  
  result_collection<- if(!is.null(dir_stac)|!is.null(collection)){
    
    # Verificar conexion con stac
    dir_data<- tryCatch({
      rstac::collections(dir_stac) %>% rstac::get_request()}, error= function(e){
        print("Unable to establish connection to the defined dir_stac")
        NULL
      })
    
    # Conectar stac con colecciones
    if(!is.null(dir_data)){
      lapply(collection, function(x){ 
        
        col_connection<- rstac::stac_search(dir_stac, collections = x) %>% rstac::get_request() 
        if(length(col_connection$features)>0){
          print( paste0("ConexiÃ³n exitosa con  la colecciÃ³n '", x) ) 
          col_connection
        }else{
          print( paste0("Problema con la colecciÃ³n '", x, "'. Por favor revise las colecciones disponibles en check_collections")); NULL  }
        
      }) %>% setNames(collection)
    }
    
  } else { print("Invalid repository url from dir_stac. Please check the url/connection defined in the rep_connect_bridge function"); NULL  }
  
  result_collection_v2<- result_collection %>% {Filter(function(x) { !is.null(x) }, .)}
  
  
  if(length(result_collection_v2)>0){   
    
    result_collection_v3<- lapply(result_collection_v2, function(x) {list(collection=x, layers_collection = sapply(x$features,function(y){names(y$assets)}));} )
    
    list(Message = paste("Se cargaron las colecciones:", paste(names(result_collection_v2), collapse = "; ")), output= result_collection_v3 )
  } else {
    list(Message= "No se encontro ninguna de las colecciones especificadas", output= NULL)
  }
  
  
}


### Ejecutar funcion
colections_stac<- load_collections(dir_stac= repository_stac$output, collection= dir_collection_names  )
if( is.null(colections_stac$output) ){  stop("No se encuentran las colecciones especificadas")  }
output_name<- "colections_stac"

  


### Guardar resultado en formato rds
setwd(folder_results)
output_RData = file.path(folder_results, paste0(output_name, ".RData"))
save(repository_stac, repository_collections, colections_stac, file= output_RData )

## Guardar resultado en formato txt
output_txt = file.path(folder_results, paste0(output_name, ".txt"))
my_output <- repository_collections %>% lapply( function(x) {gsub(",", ";", x)} ) %>% {list(repository_collections=.)}
sink(output_txt); print(colections_stac); sink()


## Borrar resultados cache
different_files<- list.files(folder_results) %>% {.[!grepl("repository_stac|repository_collections|colections_stac",.)]}
sapply(different_files, function(x) file.remove(x))


## Inprimir resultado - Interfaz Logs
colections_stac


## Imprimir resultado - Formao json
output <- list("repository_collections_txt" = output_txt, "repository_collections_RData" = output_RData)
jsonData <- rjson::toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))