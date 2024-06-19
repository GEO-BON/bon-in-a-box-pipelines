# Instalar librerias necesarias
packagesPrev<- installed.packages()[,"Package"]
packagesNeed<- list("magrittr", "terra", "raster", "sf", "fasterize", "pbapply")
lapply(packagesNeed, function(x) {   if ( ! x %in% packagesPrev ) { install.packages(x, force=F)}    })

# Cargar librerias
packagesList<-list("magrittr", "terra")
lapply(packagesList, library, character.only = TRUE)

# Definir output
outputFolder<- {x<- this.path::this.path(); paste0(gsub("/scripts.*", "/output", x), gsub("^.*/scripts", "", x)  ) }  %>% list.files(full.names = T) %>% {.[which.max(sapply(., function(info) file.info(info)$mtime))]}
# Sys.setenv(outputFolder = "/path/to/output/folder")

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
area_mask<- sf::st_read(input$dir_area)
ap<- sf::st_read(input$dir_protected)
ap <- ap %>% sf::st_transform(4326) %>% sf::st_intersection(area_mask)

# Cargar periods entrada
data_periods<- read.csv(input$data_area)
data_periods<- dplyr::mutate(data_periods, start= as.Date(start), end= as.Date(end))
data_area_total<- read.csv(input$data_area_total)

column_date<- "created_date"; column_class<- "classes"

# Ajustar tabla de entrada
data_periods_cum<- dplyr::mutate(data_periods, area_km2= cumsum(area_km2)) %>% 
  {list(., dplyr::mutate(., !!column_class := paste0("no_", .[,column_class]), area_km2= unique(data_area_total$area_km2) - area_km2) )} %>% 
  plyr::rbind.fill()

## Asignar periodos temporales al archivo espacial
dates_sf<- sf::st_drop_geometry(ap[,column_date]) %>% dplyr::distinct() %>% dplyr::mutate(date_sf= as.Date(.[,1]))
dates_sf$period <- cut(dates_sf$date_sf, breaks = c(data_periods$start, data_periods$end[nrow(data_periods)]), labels = data_periods$period)
ap_v2<- list(as.data.frame(ap), dates_sf) %>% plyr::join_all() 

ap_v3<-  sf::st_as_sf(ap_v2) %>% sf::st_transform(9377) %>% dplyr::mutate(area_km2= as.numeric(sf::st_area(.))/1000000 )
ap_vdata<- sf::st_drop_geometry(ap_v3)


#Define the table with final result
result = as.data.frame(matrix(NA,ncol = 4, nrow = 0))
colnames(result) = c("Period" ,"Protcon","Protuncon","Unprotected")

#Create the centroids for each protected areas
#Create the centroids for each protected areas
shp_centroid <- sf::st_point_on_surface(x = ap_v3)
#Create the euclidean distance matrix:
mtx_distance <- sf::st_distance(shp_centroid)
#Convert the matrix to data frame
mtx_distance=matrix(mtx_distance,nrow=nrow(ap_v3))
rownames(mtx_distance)=colnames(mtx_distance)=ap_v3$id_pa

#Define the decades reported for the protected areas creation to start the analysis
decades = as.character(unique(ap_vdata$period) )
#Create the final table with the results, the final figure is given per decade
result = as.data.frame(matrix(NA,ncol = 5, nrow = 0))
colnames(result) = c("Period" ,"Protcon","Protuncon","Protected","Unprotected")


for (i in decades) { print(i)
  
  #Filter the decade for the analysis
  decade = data_periods_cum[data_periods_cum$period==i,]
  
  #Generate the value for protected and not protected area 
  #Extract the total area of interest
  area_consult = sum(decade$area)
  #Extract the area  of interest that not intersect with any the protected area
  area_no_prot = decade[decade$classes == "no_Protected",]
  area_no_prot = sum(area_no_prot$area)
  #Extract the area for the protected areas that intersect with the area of interest
  area_protect = decade[decade$classes != "no_Protected",]
  area_protect = sum(area_protect$area)
  #Extract the percentage for unprotected area
  unprotected = ((area_consult - area_protect)/area_consult)*100
  protected = ((area_protect/area_consult))*100
  
  #Generate the value for protected areas connected (protcon)
  #Filter the unique id?s for the protected areas that intersect with the area of interest for the decade i
  table = ap_vdata[ap_vdata$period == i,]
  ids_pa = unique(table$id_pa)
  ids_pas = as.character(ids_pa)
  #Filter the distance matrix with the unique previous id's
  dist_ids_pa = as.data.frame.matrix(mtx_distance) %>% {.[ids_pas,]} %>% dplyr::select(ids_pas) %>% as.matrix()
  
  #Convert the matrix to data frame
  dist_ids_pa=data.frame(rows=rownames( dist_ids_pa)[row( dist_ids_pa)], vars=colnames( dist_ids_pa)[col( dist_ids_pa)],
                         values=c( dist_ids_pa))
  
  #Remove the distances equal to 0
  dist_ids_pa = dist_ids_pa[apply(dist_ids_pa!=0, 1, all),]
  #Remove the duplicates distances
  dist_ids_pa = dist_ids_pa[!duplicated(dist_ids_pa$values), ]
  #Filter only the protected areas that are at a distances less than user distance
  dist_ids_pa_con =dist_ids_pa[dist_ids_pa$values<input$distance, ]
  #Extract the unique id?s of protected areas at a distances less than user distance
  pa_union =union(unique(dist_ids_pa_con$row),unique(dist_ids_pa_con$vars))
  #Look for the id?s in the data for filter the information
  areas_pa_conec = ap_v3[ap_v3$id_pa %in% pa_union,]
  
  areas_conec = sum(areas_pa_conec$area_km2)
  #Extract the percentage of area for the conected protected areas (Protcon)
  protcon = (areas_conec/area_protect)*100
  
  #Generate the area for not connected protected areas 
  #Identify the rows where are the connected protected areas
  rows=which(decade$id_pa %in% pa_union)
  #Filter the table "decade" removing connected protected areas
  
  if(length(rows)==0) {
    areas_pa_no_conec = table
  } else {
    areas_pa_no_conec = table[-rows,]
  }
  
  #Extract the percentage of area for the not connected protected areas (Protuncon)
  areas_no_conec = (sum(areas_pa_no_conec$area))
  protuncon = (areas_no_conec/area_protect)*100
  
  #Create the table with the final results  
  #Create the row with the results for the decade i
  result_p= data.frame(Period = i,Protcon=protcon,Protuncon = protuncon, Protected = protected ,Unprotected=unprotected)
  #Add the previous row to the table final results
  result = rbind.data.frame(result,result_p) 
}


# Tabla de datos
dir_result_protcom<- file.path(outputFolder, "result_protcom.csv")
write.csv(result, dir_result_protcom)


# Exportar output final
output<- list( result_protcom= dir_result_protcom)

setwd(outputFolder)
jsonlite::write_json(output, "output.json", auto_unbox = TRUE, pretty = TRUE)