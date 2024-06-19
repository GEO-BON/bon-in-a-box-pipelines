# Instalar librerias necesarias
packagesPrev<- installed.packages()[,"Package"]
packagesNeed<- c("magrittr", "terra", "raster", "sf", "fasterize", "pbapply")
new.packages <- packagesNeed[!(packagesNeed %in% packagesPrev)]; if(length(new.packages)) {install.packages(new.packages, binary=T)}

# Cargar librerias
packagesList<-list("magrittr", "terra")
lapply(packagesList, library, character.only = TRUE)

# Definir output
# outputFolder<- {x<- this.path::this.path(); paste0(gsub("/scripts.*", "/output", x), gsub("^.*/scripts", "", x)  ) }  %>% list.files(full.names = T) %>% {.[which.max(sapply(., function(info) file.info(info)$mtime))]}
 Sys.setenv(outputFolder = "/path/to/output/folder")

# Definir input
input <- rjson::fromJSON(file=file.path(outputFolder, "input.json")) # Cargar input



input<- lapply(input, function(x) if( any(grepl("/output/", x)) ){
  sub(".*/output/", "/output/", x) %>%  {gsub("/output/.*", ., outputFolder)}}else{x} ) # Ajuste input 1

input <- lapply(input, function(x) { 
  if( any(tools::file_ext(x) %in% 'json') ){
    pattern<-  "/\\{\\{(.+?)\\}\\}/"
    element <-  stringr::str_extract(x, pattern) %>% {gsub("[\\{\\}/]", "", .)}
    folder_json<- gsub(pattern, "/", x) %>% dirname() %>% list.files(full.names = T) %>% {.[which.max(sapply(., function(info) file.info(info)$mtime))]}
    object<- rjson::fromJSON(file=file.path(folder_json, "output.json"))[[element]]
  } else {x}    }    ) # Ajuste input 2

input<- lapply(input, function(x) if( any(grepl("/output/", x)) ){ 
  sub(".*/output/", "/output/", x) %>%  {gsub("/output/.*", ., outputFolder)}}else{x} ) # Ajuste input 1


# Correr codigo

  # Listar layers
  dir_stack<- input$dir_stack
  files_dir_stack<- list.files(dir_stack,  "\\.tif$", recursive = TRUE)
  
  # Cargar layers
  setwd(dir_stack)
  layers<- terra::rast(files_dir_stack)
  
  # Estimar frecuencias de layers
  name_layers<- data.frame(layer_id= names(layers)) %>% dplyr::mutate(layer= seq(nrow(.)))
  freq_layers<- terra::freq(layers) %>% list(name_layers) %>% plyr::join_all() %>%
    dplyr::select(-layer) %>% dplyr::rename(layer= layer_id) %>% dplyr::mutate(area_km2=  count*(prod(res(layers)) /1000000)   )
  
  # Asignar atributos a layer
  groups<- strsplit(input$group, ",") %>% unlist() %>% base::trimws()
  metadata_layers<- read.csv(input$dir_data_layer) %>% dplyr::select(c("value", "layer", groups))
  data_layers<- list(freq_layers, metadata_layers) %>% plyr::join_all()
  data_area<- dplyr::filter(data_layers, layer %in% "area") %>%  dplyr::select(layer, area_km2)
  data_layers2<- dplyr::filter(data_layers, !layer %in% "area")
  
  # Estimar frecuencias por grupo
  data_group<- data_layers2 %>% dplyr::group_by_at(groups) %>% dplyr::summarise(area_km2= sum(area_km2))
  
  # Tabla de areas
  dir_data_areas<- file.path(outputFolder, "data_areas.csv")
  write.csv(data_group, dir_data_areas)
  
  dir_area_total<- file.path(outputFolder, "data_area_total.csv")
  write.csv(data_area, dir_area_total)
  
  
  # Exportar output final
  output<- list(dir_areas= dir_data_areas, dir_area_total= dir_area_total)

# Exportar resultado
  setwd(outputFolder)
  jsonlite::write_json(output, "output.json", auto_unbox = TRUE, pretty = TRUE)
