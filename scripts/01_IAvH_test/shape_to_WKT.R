# Instalar librerias necesarias
packagesPrev<- installed.packages()[,"Package"]
packagesNeed<- list("magrittr", "terra", "raster", "sf", "fasterize", "pbapply")
lapply(packagesNeed, function(x) {   if ( ! x %in% packagesPrev ) { install.packages(x, force=T)}    })

# Cargar librerias
packagesList<-list("magrittr", "terra")
lapply(packagesList, library, character.only = TRUE)

# Definir output
# outputFolder<- {x<- this.path::this.path(); paste0(gsub("/scripts.*", "/output", x), gsub("^.*/scripts", "", x)  ) }  %>% list.files(full.names = T) %>% {.[which.max(sapply(., function(info) file.info(info)$mtime))]}
Sys.setenv(outputFolder = "/path/to/output/folder")


# Definir input
input <- rjson::fromJSON(file=file.path(outputFolder, "input.json")) # Cargar input

input<- lapply(input, function(x) {  
  if (length(x)>0){
    if( grepl("/output/", x) ){
      sub(".*/output/", "/output/", x) %>%  {gsub("/output.*", ., outputFolder)}}else{x}
  }else {x}
} ) # Ajuste input 1

input <- lapply(input, function(x) {
  if(tools::file_ext(x) %in% 'json'){
    pattern<-  "/\\{\\{(.+?)\\}\\}/"
    element <-  stringr::str_extract(x, pattern) %>% {gsub("[\\{\\}/]", "", .)}
    folder_json<- gsub(pattern, "/", x) %>% dirname() %>% list.files(full.names = T) %>%
      {.[which.max(sapply(., function(info) file.info(info)$mtime))]}
    object<- rjson::fromJSON(file=file.path(folder_json, "output.json"))[[element]]
  } else {x}    }    ) # Ajuste input 2

input<- lapply(input, function(x) {  
  if (length(x)>0){
    if( grepl("/output/", x) ){
      sub(".*/output/", "/output/", x) %>%  {gsub("/output.*", ., outputFolder)}}else{x}
  }else {x}
} ) # Ajuste input 1


# Correr codigo
output<- tryCatch({
  
vector_polygon<-  terra::vect(input$shape_dir) %>% terra::aggregate()  %>%  terra::project(terra::crs( paste0("+init=epsg:", input$epsg) ))
wkt_polygon <- terra::geom(vector_polygon, wkt=TRUE) %>% {  paste0( "MULTIPOLYGON (",paste(gsub("POLYGON ", "", .), collapse=  ", "),")")  }

dir_wkt<- file.path(outputFolder, "wkt_polygon_test.txt")
writeLines(wkt_polygon, dir_wkt )


dir_GeoJSON<- file.path(outputFolder, "wkt_polygon_test.geojson")
geojson_polygon<- sf::st_as_sf(vector_polygon) %>% sf::st_transform(4326)
sf::st_write(geojson_polygon, dir_GeoJSON, overwrite=T)


# Definir output final 
output<- list(dir_wkt= dir_wkt,dir_GeoJSON= dir_GeoJSON, epsg= input$epsg)

}, error = function(e) { list(error= conditionMessage(e)) })


# Exportar output final
setwd(outputFolder)
jsonlite::write_json(output, "output.json", auto_unbox = TRUE, pretty = TRUE)