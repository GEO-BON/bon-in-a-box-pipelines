### Codigo para crear coleccion stac

# Cargar librerias
packages_list<-list("magrittr", "dplyr", "plyr", "pbapply", "rstac", "gdalcubes", "sf", "terra", "raster", "stringi")
lapply(packages_list, library, character.only = TRUE)   

# Cargar json base
json_base <- jsonlite::fromJSON("C:/Users/LENOVO/Desktop/Catalogs/draft_catalog.json")

# Definir nombre de la colección
name_collection<- "Corredores claves de conectividad"

# Definir directorio donde guardar la colección
dir_collection<- "C:/Users/LENOVO/Desktop/Catalogs/Biotablero_collections/Targets/Biotablero_targets_conectividad_collection" # Directorio de coleccion

# Definir capas a incluir en la coleccion
dir_layers<- "D:/IAvH 2022/Portafolios metas/aporte_metas/info_intermedia/conectividad" # Directorio de capas
metadata_layers<- read.csv("C:/Users/LENOVO/Desktop/Catalogs/scripts collection/targets.csv", header = T, encoding = "UTF-8") %>%
  setNames(gsub("X.U.FEFF.", "", names(.)))

# Crear coleccion
# Cargar lista de capas
setwd(dir_layers)
path_layers <- list.files(dir_layers, "\\.tif$", recursive = TRUE, full.names = T)

# Ajustar json
name<- gsub("-| ", "_", name_collection)
json_catalog<-json_base
json_catalog$description<- name
json_catalog<- rapply(json_catalog, function(x){gsub("biob_port", name, x)}, how = "list")


# Listar capas como bandas
list_bands<- pblapply(path_layers, function(x) {
  
  # Ajustar layer
  layer<- rast(x) %>% terra::clamp(lower=1, upper=1) %>% raster() %>% rast() # Convertir capas en valores de 1 y NA
  layer_name<- basename(tools::file_path_sans_ext(x))  %>% {gsub("-| ", "_",.)}; names(layer)<- layer_name # Asignar nombres de las capas
  band_name<- gsub("-| ", "_", layer_name) %>% {paste0(name, "-2022_12_31-", .)} # Asignar fechas de las capas
  band_metadata<- metadata_layers %>% {if("folder" %in% names(.)){dplyr::filter(., (folder %in% basename(dirname(x))) ) %>% dplyr::select(-c(folder))}else{
    . }} %>% {if("layer" %in% names(.)){dplyr::filter(., (layer %in% layer_name) ) %>% dplyr::select(-c(folder))
    }else{.}}
  
  # Exportar layer como geotiff
  setwd(dir_collection)
  terra::writeRaster(layer, paste0(band_name, ".tif"), gdal=c("COMPRESS=DEFLATE", "TFW=YES"),  filetype = "GTiff", overwrite = TRUE )
  
  # Listar parametros de la banda json
  list(
    "pattern"= paste0(".+", tools::file_path_sans_ext(band_name), "+.*\\.tif"),
    "nodata"= -9999,
    "attributes_band"= as.list(band_metadata),
    "categories"= list(1) %>% setNames(layer_name),
    "properties"= list("proj:epsg"= 4326)
  )
  
}) %>% setNames(basename(tools::file_path_sans_ext(path_layers)))

# Agregar bandas a json
json_catalog$bands<- list_bands

# Exportar json
setwd(dir_collection); jsonlite::write_json(json_catalog, "catalog.json", auto_unbox = TRUE, pretty = TRUE)
