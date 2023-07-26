# Instalar librerias necesarias
packagesPrev<- installed.packages()[,"Package"]
packagesNeed<- list("magrittr", "terra", "raster", "sf", "fasterize", "pbapply")
lapply(packagesNeed, function(x) {   if ( ! x %in% packagesPrev ) { install.packages(x, force=T)}    })

# Cargar librerias
packagesList<-list("magrittr", "terra", "raster")
lapply(packagesList, library, character.only = TRUE)

# Definir output
#  outputFolder<- {x<- this.path::this.path(); paste0(gsub("/scripts.*", "/output", x), gsub("^.*/scripts", "", x)  ) }  %>% list.files(full.names = T) %>% {.[which.max(sapply(., function(info) file.info(info)$mtime))]}
Sys.setenv(outputFolder = "/path/to/output/folder")

# Definir input
input <- rjson::fromJSON(file=file.path(outputFolder, "input.json")) # Cargar input

input<- lapply(input, function(x) if( grepl("/output/", x) ){
  sub(".*/output/", "/output/", x) %>%  {gsub("/output.*", ., outputFolder)}}else{x} ) # Ajuste input 1

input <- lapply(input, function(x) {
  if(tools::file_ext(x) %in% 'json'){
    pattern<-  "/\\{\\{(.+?)\\}\\}/"
    element <-  stringr::str_extract(x, pattern) %>% {gsub("[\\{\\}/]", "", .)}
     folder_json<- gsub(pattern, "/", x) %>% dirname() %>% list.files(full.names = T) %>% {.[which.max(sapply(., function(info) file.info(info)$mtime))]}
    object<- rjson::fromJSON(file=file.path(folder_json, "output.json"))[[element]]
  } else {x}    }    ) # Ajuste input 2

input<- lapply(input, function(x) if( grepl("/output/", x) ){
  sub(".*/output/", "/output/", x) %>%  {gsub("/output.*", ., outputFolder)}}else{x} ) # Ajuste input 1


# Correr codigo
# Definir area de estudio
ext_WKT_area<- tools::file_ext(input$WKT_area)
dir_wkt<- if(ext_WKT_area %in% "txt"){ readLines(input$WKT_area) }else{ input$WKT_area }
crs_polygon<- terra::crs( paste0("+init=epsg:", input$epsg) ) %>% as.character()
vector_polygon<- terra::vect(dir_wkt, crs=  crs_polygon ) 
  
# Ajustar resolucion
resolution_crs<- raster::raster(raster::extent(seq(4)),crs= paste0("+init=epsg:", 3395), res= input$resolution) %>% 
  raster::projectRaster( crs = crs_polygon) %>% raster::res()

box_polygon<-  sf::st_bbox(vector_polygon) %>% sf::st_as_sfc() %>% sf::st_buffer(sqrt(prod(resolution_crs))) %>% sf::st_bbox()


# crear raster base
rasterbase<- raster::raster( raster::extent(box_polygon),crs= crs_polygon, res= resolution_crs) %>% terra::rast()
study_area<- terra::rasterize(vector_polygon, rasterbase)
box_study_area<- terra::ext(study_area) %>% sf::st_bbox()
dim_study_area<- dim(study_area)







# Cargar coleccion
  if( startsWith(input$collection_path, "http://") ){ # Cuando proviene de una coleccion en linea
    
    RSTACQuery<- rstac::stac(input$collection_path)
    box_4326 <-  sf::st_as_sfc(box_polygon) %>% sf::st_transform(4326) %>% sf::st_bbox()
    STACItemCollection <- rstac::stac_search(q= RSTACQuery, collections = "chelsa-clim" , bbox = box_4326) %>% rstac::get_request()
    assets<- unlist(lapply(STACItemCollection$features,function(y){names(y$assets)})) %>% unique()
    image_collection <- gdalcubes::stac_image_collection(STACItemCollection$features, asset_names = assets )

  } else { # Cuando proviene de una coleccion local
    
    layers_collection <- list.files(input$collection_path, "\\.tif$", recursive = TRUE, full.names = TRUE)
    json_colleciton_file <- list.files(input$collection_path, "\\.json$", recursive = TRUE, full.names = TRUE)
    STACItemCollection <-   rjson::fromJSON(file= json_colleciton_file)
    image_collection <- gdalcubes::create_image_collection(files= layers_collection, format= json_colleciton_file)
    
  }
  
# Cargar assests metadata
assets_metadata<- STACItemCollection$features %>% purrr::map("assets") %>% {setNames(unlist(., recursive = F), sapply(., function(y) names(y)))}


# Redondear temporaldiad del cubo
type_period<- tryCatch({ sub(".*P", "", input$time_period) %>% {period= as.numeric(gsub("([0-9]+).*$", "\\1", .)); type= gsub(period,"", .); list(type=type, period=period) }
}, error= function(e){ list(type=type, period=period) })
  
t0<- gdalcubes::extent(image_collection)$t0
t1<- gdalcubes::extent(image_collection)$t1

t0<-if(!input$time_start %in% "NA"){ tryCatch(as.Date(input$time_start), error= function(e){t0}) }else{t0}
t0<- (if(type_period$type == "Y"){ lubridate::floor_date(as.Date(t0),  lubridate::years(type_period$period))
} else if (type_period$type == "M") { lubridate::floor_date(as.Date(t0),  months(type_period$period) )
} else if( type_period$type == "D"){ lubridate::floor_date(as.Date(t0),  lubridate::days(type_period$period) )
  } else{as.Date(t0)}) %>% paste0("T00:00:00")

t1<-if(!input$time_start %in% "NA"){ tryCatch(as.Date(input$time_end), error= function(e){t1}) }else{t1}
t1<- (if(type_period$type == "Y"){ lubridate::ceiling_date(as.Date(t1),  lubridate::years(type_period$period))
} else if (type_period$type == "M") { lubridate::ceiling_date(as.Date(t1),  months(type_period$period) )
} else if( type_period$type == "D"){ lubridate::ceiling_date(as.Date(t1),  lubridate::days(type_period$period) )
} else{as.Date(t1)}) %>% paste0("T00:00:00")







# Establecer cube view
cube_collection<- gdalcubes::cube_view(srs = crs_polygon,  extent = list(t0 = t0, t1 = t1,
                                                                           left = box_study_area[1], right = box_study_area[3],
                                                                           top = box_study_area[4], bottom = box_study_area[2]),
                                         nx = dim_study_area[2], ny = dim_study_area[1], dt = "P1Y",aggregation = "near", resampling = "first",
                                         keep.asp= F)

# Crear cubo
cube <- gdalcubes::raster_cube(image_collection, cube_collection)

# Descargar cubo
fn = tempfile(fileext = ".nc"); gdalcubes::write_ncdf(cube, fn)
nc <-  ncdf4::nc_open(fn); vars <- names(nc$var)

# Ordenar temporalidad del cubo
cube_times<- as.data.frame(gdalcubes::dimension_bounds(cube)[["t"]])
cube_times

nc_times<- if(nrow(cube_times)<2){"X0"}else{ paste0("X", ncdf4::ncvar_get(nc, "time_bnds")[1,]) }
time_collection<- as.data.frame(gdalcubes::dimension_bounds(cube)[["t"]]) %>% dplyr::mutate(time_id= nc_times, dim3=seq(nrow(.)))

# Organizar cubo como raster
terra_mask<- pbapply::pblapply(vars[5:length(vars)], function(x){ print(x)
  
  # Dimensiones de la capa
  dims_var <- ncdf4::ncvar_get(nc, x)
  
  # Validar si la capa esta vacia
  key<-  as.data.frame(which(!is.na(dims_var),  arr.ind = TRUE))

  if(nrow(key)>0){ 
    
    # Cargar capa raster
    key2<- {if(nrow(cube_times)<2){ dplyr::mutate(key, time_id= "X0") }else{ key }} %>% {list(., time_collection)} %>% plyr::join_all()
    brick  <- raster::brick(fn, var= x) %>% terra::rast() %>% terra::resample(study_area, method= "near") %>% terra::mask(study_area)
    
    times<- unique(key2$time_id) 
    layer <- brick[[ times ]];
    
    # Organizar metadatos de la capa
    metadata_band<- assets_metadata[[x]]
    metadata_assest<- metadata_band %>% { .[!c(names(.) %in% c("type", "raster:bands"))]  } %>%
      lapply(function(z) if(length(z)>1){if(class(z) %in% "list"){data.frame(z)}else{NULL}
      }else{z}   )  %>% {Filter(function(x) !is.null(x), .)}
    check_data<- names(metadata_assest)[!sapply(metadata_assest, function(x) class(x) %in% "data.frame")]
    for(j in check_data){ metadata_assest[[j]]<- data.frame(metadata_assest[j])}
    
    
    # Organizar cuando hay "value" en metadata
    which_values<- unlist(sapply(metadata_assest, function(x) "value" %in% names(x)))
    metadata_assest2<- metadata_assest[which(!which_values)]
    suppressMessages({metadata_assest2<- dplyr::bind_cols(metadata_assest2) %>% dplyr::mutate(layer= x)})
    
   
    
    
    # Organizar informacion de la capa
    info_layer<- dplyr::distinct(key2[, c("start", "end")]) %>% dplyr::distinct() %>% 
      dplyr::mutate(period= paste(start, end, sep="_"), layer= x) %>% 
      list(metadata_assest2)  %>% plyr::join_all() %>% 
      dplyr::mutate(layer= gsub( "[[:punct:]]", "_", paste(x, period, sep = "_") ) ) %>% 
      dplyr::mutate(file= paste0(layer, ".tif") ) %>% 
      dplyr::relocate("layer", .before = 1)

    # Organizar nombre de la capa
    names(layer)<- info_layer$layer
    
    # Organizar datos de la capa
    data_layer<-  setNames(as.data.frame(layer), "value") %>% dplyr::mutate(layer= names(layer)) %>% dplyr::relocate("layer", .before = 1) %>% 
      dplyr::distinct() %>% list(info_layer)  %>% plyr::join_all()
    
    # Asignar "value" a los datos
    if(sum(which_values)>0){
      metadata_values<- metadata_assest[which(which_values)][[1]]; class_names<- names(metadata_values) %>% {.[!. %in% "value"]}
      data_layer2<- list(data_layer, metadata_values ) %>% plyr::join_all()
      if(length(class_names)>0){data_layer<- dplyr::relocate(data_layer2, class_names, .after = "value")}
    }
    
    list(layer=layer, info_layer= info_layer, data_layer= data_layer)
    
  } else {NULL}
  
})  %>% {Filter(function(x) !is.null(x), .)} 




# Tabla de informacion
dir_info_layer<- file.path(outputFolder, "info_layer.csv")
info_layers<- purrr::map(terra_mask, "info_layer") %>% plyr::rbind.fill()
write.csv(info_layers, dir_info_layer)

# Tabla de datos
dir_data_layer<- file.path(outputFolder, "data_layer.csv")
data_layers<- purrr::map(terra_mask, "data_layer") %>% plyr::rbind.fill()
write.csv(data_layers, dir_data_layer)

# Guardar layers
terra_mask_layers<- purrr::map(terra_mask, "layer") %>%  # Anadir layer area de estudio
  {c(., list(area= study_area ))} %>% terra::rast()


dir_stack<- file.path(outputFolder, "dir_stack")
unlink(dir_stack, recursive = TRUE); dir.create(dir_stack); setwd(dir_stack)

setwd(dir_stack)
lapply(terra_mask_layers, function(x)
    terra::writeRaster(x, paste0(names(x), ".tif"), gdal=c("COMPRESS=DEFLATE", "TFW=YES"),  filetype = "GTiff", overwrite = TRUE ))


# Exportar area rasterizada 4326
dir_area_4326<- file.path(outputFolder, "dir_area_4326.tif")
area_4326<-  terra::project(terra_mask_layers$area,  paste0("+init=epsg:", 4326) )
terra::writeRaster(area_4326, dir_area_4326, gdal=c("COMPRESS=DEFLATE", "TFW=YES"),  filetype = "GTiff", overwrite = TRUE )



# Estimar frecuencias de layers
layers<- terra_mask_layers
name_layers<- data.frame(layer_id= names(layers)) %>% dplyr::mutate(layer= seq(nrow(.)))
freq_layers<- terra::freq(layers) %>% list(name_layers) %>% plyr::join_all() %>%
  plyr::mutate(area =  count*(input$resolution /10000 )   ) %>% 
  dplyr::select(- c("layer", "count")) %>% dplyr::rename(layer= layer_id)


# Asignar atributos a layer
data_areas<- list( dplyr::filter(freq_layers, !layer %in% "area") , data_layers) %>% plyr::join_all() 
data_areas2<- data_areas %>% 
  dplyr::group_by(period_layer) %>%  dplyr::mutate(percentage= area/ sum(area)) %>% 
  dplyr::select(period_layer, classes, layer, value, area, percentage)

# Tabla de areas
dir_data_areas<- file.path(outputFolder, "data_areas.csv")
write.csv(data_areas2, dir_data_areas)



# Tabla de areas json
table_pp<- jsonlite::toJSON(data_areas2)



# Exportar imagenes de los raster
dir_png<- file.path(outputFolder, "dir_png")
unlink(dir_png, recursive = TRUE); dir.create(dir_png); setwd(dir_png)


saveraster<- lapply( seq(nrow(data_areas)), function(i) { print(i)
  
  x<- data_areas[i, ]
  
  raster_val<- terra_mask_layers[x$layer]
  raster_val[!raster_val %in% x$value]= NA
  raster_val[raster_val %in% x$value]= 1
  
  # colorear plot y exportar con buena resolucion
  r<- raster(raster_val)
  
  setwd(dir_png)
  png( paste0( paste(c("forestLP", x$period_layer, x$classes), collapse = "-") ,  ".png"),
       width = 1000, height = 1000, units = "px", res=300 )
  
  plot.new()
  par(mar=c(0,0,0,0), oma=c(0,0,0,0), bg=NA)
  plot.new()
  
  plot.window(xlim= raster::extent(r)[1:2], ylim= raster::extent(r)[3:4], xaxs="i",yaxs="i")
  plot(r, axes=F, legend=F, add=T, col= x$col)
  
  dev.off(); 
  
  
} )


# Exportar output final
output<- list( area_stack= dir_area_4326, dir_stack= dir_stack, dir_png=dir_png, dir_info_layer= dir_info_layer,
               dir_data_layer=dir_data_layer, dir_data_areas= dir_data_areas, table_pp=table_pp)
  
setwd(outputFolder)
jsonlite::write_json(output, "output.json", auto_unbox = TRUE, pretty = TRUE)