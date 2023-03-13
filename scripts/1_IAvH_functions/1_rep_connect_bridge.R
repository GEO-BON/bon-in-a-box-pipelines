### función rep_connect_bridge

# Cargar librerias
packages_list<-list("magrittr")
invisible(lapply(packages_list, library, character.only = TRUE))

# Organizar directorios
Sys.setenv(OUTPUT_FOLDER = "/path/to/output/folder")


print("outputFolder")
print(outputFolder)

# Cargar archivos de entrada
input <- rjson::fromJSON(file=file.path(outputFolder, "input.json"))

### Generar función
rep_connect_bridge<- function(repository_url){
  ## Check url validity
  dir_stac<- tryCatch({httr::GET(repository_url); repository_url}, error= function(e){NULL})
  if(!is.null(dir_stac)){
    list(Message = "Valid url - connection repository address defined succeed; output= T", output= rstac::stac(dir_stac))
  } else {
    list(Message= "Invalid repository url. Please enter a valid repository url; output= NULL", output= NULL)
  }
}

### Ejecutar funcion
repository_stac <- rep_connect_bridge(repository_url = input$repository_url)
output_name<- "repository_stac"

# Crear folder de salida
folder_name<- tools::file_path_sans_ext(input$filename_repository_stac)
folder_results<- paste0(dirname(dirname(dirname(outputFolder))), "/", input$folder_workflow)
invisible({dir.create(folder_results)}); setwd(folder_results)

### Guardar resultado en formato .RData
setwd(folder_results)
output_RData = file.path(folder_results, paste0(output_name, ".RData"))
save(repository_stac, file= output_RData )

## Guardar resultado en formato txt
setwd(folder_results)
output_txt =  file.path(folder_results, paste0(output_name, ".txt"))
my_output <- repository_stac %>% {gsub(",", ";", .)} %>% {list(repository_stac=.)}
sink(output_txt); print(my_output); sink()

## Borrar resultados cache
different_files<- list.files(folder_results) %>% {.[!grepl("repository_stac", .)]}
sapply(different_files, function(x) file.remove(x))


## Inprimir resultado - Interfaz Logs
repository_stac



## Imprimir resultado - Formato json
output <- list("repository_stac_txt" = output_txt, "repository_stac_RData" = output_RData)
jsonData <- rjson::toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))