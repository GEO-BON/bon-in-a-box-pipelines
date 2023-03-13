### función check_collections

# Cargar librerias
packages_list<-list("magrittr")
invisible(lapply(packages_list, library, character.only = TRUE))

# Organizar directorios
Sys.setenv(OUTPUT_FOLDER = "/path/to/output/folder")

# Cargar archivos de entrada
input <- rjson::fromJSON(file=file.path(outputFolder, "input.json"))
folder_name<- tools::file_path_sans_ext(input$folder_workflow)
folder_results<- paste0(dirname(dirname(dirname(outputFolder))), "/", input$folder_workflow)
dir_stac_file<- paste0(input$dir_stac, ".RData")

if(file.exists(folder_results)){ setwd(folder_results); 
  if(file.exists(dir_stac_file)){
    load(dir_stac_file); 
  } else { stop("No se encuentra el archivo dir_stac especificado") 
  }
  } else{ stop("No se encuentra el folder_workflow especificado") }


if(!exists("repository_stac")){
  stop("Error al cargar archivo dir_stac especificado")
} 


### Generar función
check_collections<- function(dir_stac= NULL){
  
  if(!is.null(dir_stac)){
    
    dir_data<- tryCatch({
      rstac::collections(dir_stac) %>% rstac::get_request()}, error= function(e){
        print("Unable to establish connection to the defined dir_stac")
        NULL
      })
    
  } else { print("Invalid repository url from dir_stac. Please check the url/connection defined in the rep_connect_bridge function")  }
  
  
  if(!is.null(dir_data)){   
    list(Message = "Valid repository - review of collections repository defined succeed; Colecciones disponibles:", output= sapply(dir_data$collections, function(x) x$id) )
  } else {
    list(Message= "Invalid repository url from dir_stac. Please check the url/connection defined in the rep_connect_bridge function", output= NULL)
  }
  
}

### Ejecutar funcion
repository_collections<- check_collections(dir_stac= repository_stac$output)
output_name<- "repository_collections"



### Guardar resultado en formato rds
setwd(folder_results)
output_RData = file.path(folder_results, paste0(output_name, ".RData"))
save(repository_stac, repository_collections, file= output_RData )

## Guardar resultado en formato txt
output_txt = file.path(folder_results, paste0(output_name, ".txt"))
my_output <- repository_collections %>% lapply( function(x) {gsub(",", ";", x)} ) %>% {list(repository_collections=.)}
sink(output_txt); print(repository_collections); sink()

## Borrar resultados cache
different_files<- list.files(folder_results) %>% {.[!grepl("repository_stac|repository_collections",.)]}
sapply(different_files, function(x) file.remove(x))


## Inprimir resultado - Interfaz Logs
repository_collections


## Imprimir resultado - Formao json
output <- list("repository_collections_txt" = output_txt, "repository_collections_RData" = output_RData)
jsonData <- rjson::toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))