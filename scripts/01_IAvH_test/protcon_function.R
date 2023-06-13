

# Organizar directorios
Sys.setenv(OUTPUT_FOLDER = "D:/GEOBON/biab-2.0/output") #pegando al output que jean michael copió, para guardar en la misma carpeta

# Cargar archivos de entrada
input <- rjson::fromJSON(file=file.path(outputFolder, "input.json"))

#This routine is for develop the connectivity indices (prtcon, unprotcon, protected area, unprotected area)
#Inputs
#Table where are the protected areas that intersect with the area of interest
data = data_out #input$data
#data = read.csv(input$data)


#Put the path where ir the protected areas layers, make sure that each areas has a id unique
ap = st_read("C:/Users/LENOVO/Downloads/geo_protected_areas_corrected_duplic.gpkg") 
#ap= st_read(input$ap)
#Define the distance that the user give for the connectivity analysis, in meters
distance = 3000
#input$distance
#Define the url where the result will be save
outputFolder = "D:/GEOBON/biab-2.0/output"


  #load_libraries("sf") #Mirar cuáles librerías uso, y decirle a Victor que conecte load_libraries
#Define the table with final result
  result = as.data.frame(matrix(NA,ncol = 4, nrow = 0))
  colnames(result) = c("Period" ,"Protcon","Protuncon","Unprotected")
#Generate the distance matrix for all the country  
  #Project the layer of protected areas for the national origin for Colombia to generate distances in meters
  ap=st_transform(ap, 9377)
  #Create the centroids for each protected areas
  shp_centroid <- st_point_on_surface(x = ap)
  #Create the euclidean distance matrix:
  mtx_distance <- st_distance(shp_centroid)
  #Convert the matrix to data frame
  mtx_distance=matrix(mtx_distance,nrow=nrow(ap))
  rownames(mtx_distance)=colnames(mtx_distance)=ap$id_pa
  
  #Define the decades reported for the protected areas creation to start the analysis
  decades = unique(data$period) 
  #Create the final table with the results, the final figure is given per decade
  result = as.data.frame(matrix(NA,ncol = 5, nrow = 0))
  colnames(result) = c("Period" ,"Protcon","Protuncon","Protected","Unprotected")
  
  for (i in decades) {
    #Filter the decade for the analysis
    decade = data[data$period==i,]
    
  #Generate the value for protected and not protected area 
    #Extract the total area of interest
    area_consult = sum(decade$area) 
    #Extract the area  of interest that not intersect with any the protected area
    area_no_prot = decade[decade$id_pa == "no_protected",]
    area_no_prot = sum(area_no_prot$area)
    #Extract the area for the protected areas that intersect with the area of interest
    area_protect = decade[decade$id_pa != "no_protected",]
    area_protect = sum(area_protect$area)
    #Extract the percentage for unprotected area
    unprotected = ((area_consult - area_protect)/area_consult)*100
    protected = ((area_protect/area_consult))*100
    
  #Generate the value for protected areas connected (protcon)
    #Filter the unique id´s for the protected areas that intersect with the area of interest for the decade i
    table = decade[decade$id_pa != "no_protected",]
    ids_pa = unique(table$id_pa)
    ids_pas = as.character(ids_pa)
    
    #Filter the distance matrix with the unique previous id's
    dist_ids_pa = mtx_distance [colnames(mtx_distance) %in% ids_pas,rownames(mtx_distance) %in% ids_pas ] 
    
    #Convert the matrix to data frame
    dist_ids_pa=data.frame(rows= ids_pas, vars= ids_pas,
                           values=c( dist_ids_pa))
    
    
    #Remove the distances equal to 0
    dist_ids_pa = dist_ids_pa[apply(dist_ids_pa!=0, 1, all),]
    #Remove the duplicates distances
    dist_ids_pa = dist_ids_pa[!duplicated(dist_ids_pa$values), ]
    #Filter only the protected areas that are at a distances less than user distance
    dist_ids_pa_con =dist_ids_pa[dist_ids_pa$values<distance, ]
    #Extract the unique id´s of protected areas at a distances less than user distance
    pa_union =union(unique(dist_ids_pa_con$row),unique(dist_ids_pa_con$vars))
    #Look for the id´s in the data for filter the information
    areas_pa_conec = decade[decade$id_pa %in% pa_union,]
    areas_conec = sum(areas_pa_conec$area)
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
  
  write.csv(result,paste0(outputFolder,"/protcon.csv"),row.names = F)




