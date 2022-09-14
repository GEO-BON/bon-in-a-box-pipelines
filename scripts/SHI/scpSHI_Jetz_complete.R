#This script joins different sections to calculate the species habitat index 
#according to what is understood from the methodology Walter Jetz's team uses 
#for this calculation and compares the use of different land cover sources
#-------------------------------------------------------------------------------------------------------------------
#0. Load libraries and define Parameters
#-------------------------------------------------------------------------------------------------------------------
# Script location can be used to access other scripts
print(Sys.getenv("SCRIPT_LOCATION"))

## Install required packages
packages <- c("devtools","tidyverse","remotes","purrr","tmap","raster","ggsci","readr",
              "rgbif","rgdal","sf","httr","jsonlite","landscapemetrics","rjson","stars",
              "gdalcubes","rstac","RColorBrewer","RCurl","stacatalogue","tmaptools")

new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

lapply(packages,require,character.only=T)

## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")

input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

#Define species
sp <- input$species

#Define CRS 
ref_system <- input$ref_system
epsg <- make_EPSG()
epsg_crs <- CRS(na.exclude(epsg$prj4[epsg$code==ref_system])[1]) 
sf_crs <- st_crs(ref_system)
srs_cube <- paste0("EPSG:",ref_system)

#margin for elevation range
elev_margin <- input$elev_margin
#forest threshold for GFW
forest_threshold <- input$forest_threshold #USE MAP OF LIFE VALUES!!*****
#define country if the area of analysis will be restricted to a specific country
country_code <- input$country_code

#spatial resolution
spat_res <- input$spat_res

#Define source of expert range maps
expert_source <- input$expert_source

#define time steps
t_0 <- input$t_0
t_n <- input$t_n # should be larger than t_0 at least 2 years needed
time_step <- input$time_step
t_range <- ((t_n - t_0)/time_step)
v_time_steps <- seq(t_0,t_n,time_step)

#credentials
token <- Sys.getenv("IUCN_TOKEN")

#Filter source for land cover, global or colombia
# LC_source <- input$lc_source

## Receiving args
args <- commandArgs(trailingOnly=TRUE)
outputFolder <- args[1] # Arg 1 is always the output folder
cat(args, sep = "\n")

#-------------------------------------------------------------------------------------------------------------------
#1. Species distribution range
#-------------------------------------------------------------------------------------------------------------------
#1.1 Load expert range maps-------------------------------------------------------------
#Define species class
res <- GET(paste0("https://apiv3.iucnredlist.org/api/v3/species/",sp,"?token=",token))
js_IUCN_sheet <- rawToChar(res$content)
df_IUCN_sheet <- do.call(rbind,fromJSON(js_IUCN_sheet)$result) |> as.data.frame() 

class <- stringr::str_to_sentence(df_IUCN_sheet$class) # taxonomic group to choose data source to download maps for IUCN
order <- stringr::str_to_sentence(df_IUCN_sheet$order) # taxonomic group to choose data source to download maps for MOL

#Get range map #filter by expert source missing
if(expert_source=="IUCN"){
  sf_range_map <- sf::st_read(paste0("https://object-arbutus.cloud.computecanada.ca/bq-io/io/",expert_source,"_rangemaps/",gsub(" ","%20",sp),".gpkg"))
}else{
  sf_range_map <- sf::st_read(paste0("https://object-arbutus.cloud.computecanada.ca/bq-io/io/",expert_source,"_rangemaps/",gsub(" ","%20",sp),".gpkg"))
}


#get bounding box cropped by country if needed
if(!is.na(country_code)){
  sf_area_lim1 <- getData('GADM', country=country_code, level=0) %>% st_as_sf() %>% st_make_valid()# %>% st_transform(st_crs("wgs84"))
  sf_area_lim1_crs <- sf_area_lim1 %>% st_transform(sf_crs)
  
  sf_area_lim2 <- sf_range_map %>% st_make_valid
  sf_area_lim2_crs <- sf_area_lim2 %>% st_transform(sf_crs)
  
  sf_area_lim <- st_intersection(sf_area_lim2,sf_area_lim1 %>% st_transform(st_crs(sf_area_lim1)))#issue NOT SOLVED
  sf_area_lim_crs <- st_intersection(sf_area_lim2_crs,sf_area_lim1_crs) %>% st_make_valid()
  
  sf_ext <- st_bbox(sf_area_lim %>% st_buffer(10))
  sf_ext_crs <- st_bbox(sf_area_lim_crs %>% st_buffer(10))
}else{
  sf_area_lim <- sf_range_map
  sf_area_lim_crs <- sf_area_lim %>% st_transform(sf_crs)
  sf_ext <- st_bbox(sf_area_lim %>% st_buffer(10)) 
  sf_ext_crs <- st_bbox(sf_area_lim_crs %>% st_buffer(10))
}

#1.4 Final range----------------------------------------------------------------
#Create raster
r_frame <- raster(raster::extent(sf_ext_crs),resolution=spat_res,crs=epsg_crs)
values(r_frame) <- rep(1,ncell(r_frame))
r_suitability_map <- raster::mask(r_frame,as(sf_area_lim_crs,"Spatial"))

#-------------------------------------------------------------------------------------------------------------------
#2. Habitat Preferences
#-------------------------------------------------------------------------------------------------------------------
#2.1 Load elevation preferences---------------------------------------------
df_IUCN_sheet_condition <- df_IUCN_sheet |> mutate(
  min_elev= case_when( #evaluate if elevation ranges exist and add margin if included
  is.null(elevation_lower) ~ NA_real_,
  !is.null(elevation_lower) & as.numeric(elevation_lower) < elev_margin ~ 0,
  !is.null(elevation_lower) & as.numeric(elevation_lower) >= elev_margin ~ as.numeric(elevation_lower) - elev_margin),
  max_elev= case_when(
  is.null(elevation_upper) ~ NA_real_,
  !is.null(elevation_upper) ~ as.numeric(elevation_upper) + elev_margin),
  condition= case_when( #generate possible options according to availability of minimum and maximum elevation values
  is.na(min_elev)  & is.na(max_elev)  ~ 1, # when there is no data for elevation ranges
  !is.na(min_elev) & !is.na(max_elev) ~ 2, # when the elevation ranges are available
  !is.na(min_elev) & is.na(max_elev)  ~ 3, # when there is just data for the maximum elevation
  is.na(min_elev)  & !is.na(max_elev) ~ 4) # when there is just data for the minimum elevation
)

with(df_IUCN_sheet_condition, if(condition == 1){ # if no elevation values are provided then the suitability map stays the same
  r_suitability_map <- terra::rast(r_suitability_map)
}else{ # at least one elevation range exists then create cube_STRM to filter according to elevation ranges
  # STRM from Copernicus
  cube_STRM <- 
    load_cube(stac_path = "https://planetarycomputer.microsoft.com/api/stac/v1/",
              limit = 1000, 
              collections = c("cop-dem-glo-90"), 
              use.obs = F,
              buffer.box = 0,
              bbox = sf_ext_crs,
              srs.cube = srs_cube,
              spatial.res = spat_res,
              temporal.res = "P1Y",
              t0 = "2021-04-22",
              t1 = "2021-04-22",
              resampling = "bilinear")
  if(condition == 2){ # if both values exist
    cube_STRM_range <- cube_STRM |> 
      gdalcubes::filter_pixel(paste0("data <=", df_IUCN_sheet_condition$max_elev)) |> 
      gdalcubes::filter_pixel(paste0("data >= ", min_elev)) |> select_bands("data")
  }else{ # if only one value exist
    if(condition == 3){ # if just maximum elevation available filter by that
      cube_STRM_range <- cube_STRM |> 
        gdalcubes::filter_pixel(paste0("data <=", max_elev)) |> select_bands("data")
    }
    if(condition == 4){ # if just minimum elevation available filter by that
      cube_STRM_range <- cube_STRM |> 
        gdalcubes::filter_pixel(paste0("data >= ", min_elev)) |> select_bands("data")
    }
  }
  #convert to raster
  r_STRM_range <- cube_STRM_range  |> st_as_stars() |> terra::rast()
  
  #resample to raster of SDM
  r_STRM_range_res <- terra::resample(r_STRM_range, terra::rast(r_suitability_map))
  r_suitability_map <- terra::mask(terra::crop(terra::rast(r_suitability_map),r_STRM_range_res),r_STRM_range_res) #Crop LC to suitability extent
  }
)

#2.2 Load habitat preferences---------------------------------------------
habitat <- GET(paste0("https://apiv3.iucnredlist.org/api/v3/habitats/species/name/",sp,"?token=",token))
js_IUCN_habitat_cat <- rawToChar(habitat$content)
df_IUCN_habitat_cat <- do.call(rbind,fromJSON(js_IUCN_habitat_cat)$result) |> as.data.frame() |> mutate_if(is.list,as.character)

#Load table with land cover equivalences need to be updated with Jung et al
df_IUCN_to_LC_categories <- read.csv("./IUCN_to_LC_categories.csv",colClasses = "character") # PENDING PUT 0.5 TO MARGINAL HABITATS
df_IUCN_habitat_LC_cat <- left_join(df_IUCN_habitat_cat,df_IUCN_to_LC_categories, by="code")
LC_codes <- as.numeric(unique(df_IUCN_habitat_LC_cat$ESA_cod))

print(outputFolder)

img_map_habitat_changes <- tm_shape(r_suitability_map)+tm_raster()+
  tm_shape(sf_area_lim)+tm_borders(lwd=0.5)+
  tm_scale_bar()+tm_legend(show=F)

# img_map_habitat_changes

tmap_save(img_map_habitat_changes, paste0(outputFolder,sp,"_GFW_change.png"))

# 
# #2.3 Hydrological features---------------------------------------------
# 
# 
# #-------------------------------------------------------------------------------------------------------------------
# #3. Land Cover Values
# #-------------------------------------------------------------------------------------------------------------------
# #This script needs the suitability map, the polygon for the limits
# #this script requires sh_suitability_bbox (from scpRunMaxentModel), sf_area_lim (from scpLoadWorldClim), epsg_crs,
# #-------------------------------------------------------------------------------
# #3.1 GFW data
# #-------------------------------------------------------------------------------
# #forest base map
# cube_GFW_TC <- 
#   load_cube(stac_path = "https://io.biodiversite-quebec.ca/stac/",
#             limit = 1000, 
#             collections = c("gfw-treecover2000"), 
#             use.obs = F,
#             buffer.box = 0,
#             bbox = sf_ext_crs,
#             srs.cube = srs_cube,
#             spatial.res = spat_res,
#             temporal.res = "P1Y",
#             t0 = "2000-01-01",
#             t1 = "2000-01-01",
#             resampling = "bilinear")
# 
# cube_GFW_TC_range <- cube_GFW_TC |>
#   gdalcubes::filter_pixel(paste0("data >=", forest_threshold)) |>#filter to forest threshold 0-100
#   gdalcubes::apply_pixel(paste0("data/data")) # turn into a forest presence map
# 
# r_GFW_TC_range <- cube_to_raster(cube_GFW_TC_range , format="terra") # convert to raster format
# 
# r_suitability_map_rescaled <- terra::resample(terra::rast(r_suitability_map),r_GFW_TC_range,method="bilinear") #Adjust scale of suitability map
# r_GFW_TC_range_mask <- r_GFW_TC_range |> 
#   terra::classify(rcl=matrix(c(NA,0),ncol=2,byrow=T)) |> # turn NA to 0
#   terra::mask(r_suitability_map_rescaled) # crop to suitability map
# 
# #Download loss maps and create different layers for each year to remove from forest
# s_obj <- stac("https://io.biodiversite-quebec.ca/stac/")
# 
# it_obj <- s_obj |>
#   stac_search(collections = "gfw-lossyear",
#               bbox = sf_ext) |>
#   get_request()
# 
# st <- gdalcubes::stac_image_collection(it_obj$features, asset_names = c("data")) # create image collection
# 
# v <- cube_view(srs = srs_cube, extent = list(t0 = "2000-01-01", t1 = "2000-01-01", # create cube according to area of interest
#                                              left = sf_ext_crs['xmin'], right =sf_ext_crs['xmax'],  
#                                              top = sf_ext_crs['ymin'], bottom =  sf_ext_crs['ymax']),
#                dx=spat_res, dy=spat_res, dt="P1Y",
#                resampling = "near") # TO CHANGE to proportions
# 
# times <- as.numeric(substr(v_time_steps[v_time_steps>2000],start=3,stop=4)) #get year of change by selected time step to mask map by year of change
# l_r_year_loss <- map(times, function(x) {
#   layer <- raster_cube(image_collection=st, view=v, 
#                        mask=image_mask("data", values = times[times<=x],invert=T)) # to remove it to the following years
#   
#   layer <- layer |>
#     stars::st_as_stars() |>
#     terra::rast()
#   return(layer)
# })
# 
# #add background and mask to suitable area
# s_year_loss <- terra::classify(terra::rast(l_r_year_loss), rcl=matrix(c(NA,NA,0,1,Inf,1),ncol=3,byrow=T),include.lowest=T)
# names(s_year_loss) <- paste0("Loss_",v_time_steps[v_time_steps>2000])
# s_year_loss_mask <- terra::mask(s_year_loss,r_suitability_map_rescaled)
# 
# #update reference forest layer if t_0 different of 2000
# if(t_0!=2000){
#   r_GFW_TC_range_mask <- terra::classify(r_GFW_TC_range_mask - s_year_loss_mask[[paste0("Loss_",t_0)]],rcl=matrix(c(-1,0),ncol=2,byrow=T))
# }
# 
# cube_GFW_gain <- 
#   load_cube(stac_path = "https://io.biodiversite-quebec.ca/stac",
#             limit = 1000, 
#             collections = c("gfw-gain"), 
#             use.obs = F,
#             buffer.box = 0,
#             bbox = sf_ext_crs,
#             srs.cube = srs_cube,
#             spatial.res = spat_res,
#             temporal.res = "P1Y",
#             t0 = "2000-01-01",
#             t1 = "2000-12-31",
#             resampling = "near")
# 
# r_GFW_gain <- cube_to_raster(cube_GFW_gain %>%
#                                stars::st_as_stars(), format="terra") # convert to raster format
# r_GFW_gain_mask <- terra::classify(terra::mask(r_GFW_gain ,r_suitability_map_rescaled),matrix(c(0,NA),ncol=2,byrow = T))
# 
# #-------------------------- figure ----------------------------------------------
# osm <- read_osm(sf_area_lim, ext=1.1)
# 
# s_year_loss_mask_plot <- terra::classify(s_year_loss_mask,matrix(c(0,NA),ncol=2,byrow=T)) # turn 0 to NA
# 
# # tmap_mode("view")
# img_map_habitat_changes <- tm_shape(osm) + tm_rgb()+
#   tm_shape(r_GFW_TC_range_mask)+tm_raster(style="cat",alpha=0.8,palette = c("#0000FF00","blue"))+
#   tm_shape(terra::merge(s_year_loss_mask_plot))+tm_raster(style="cat",alpha=0.4,palette = c("#FF000080"))+#tm_facets(ncol=1,nrow=1)+
#   tm_shape(r_GFW_gain_mask)+tm_raster(style="cat",alpha=0.8,palette = c("#FFFF0080"))+
#   tm_shape(sf_area_lim)+tm_borders(lwd=0.5)+
#   # tm_shape(sf_GBIFData)+tm_dots(alpha=0.5)+
#   tm_scale_bar()+tm_legend(show=F)
# 
# # img_map_habitat_changes
# 
# tmap_save(img_map_habitat_changes, paste0(outputFolder,sp,"_GFW_change.png"))
# 
# #create layers of forest removing loss by year
# s_HabitatArea <- terra::classify(r_GFW_TC_range_mask-s_year_loss_mask , rcl=matrix(c(-1,0),ncol=2))
# s_HabitatArea <- c(r_GFW_TC_range_mask, s_HabitatArea) # if t0 is 2000
# names(s_HabitatArea) <- paste0("Habitat_",v_time_steps)
# 
# s_Habitat <- terra::classify(s_HabitatArea , rcl=matrix(c(0,NA),ncol=2))
# 
# r_HabitatFull <- terra::classify(terra::app(s_HabitatArea,fun=sum), matrix(c(-Inf,0,NA,1,Inf,1),ncol=3,byrow=T))
# 
# writeRaster(s_Habitat,filename = paste0(outputFolder,sp,"_habitat_GFW.tif"),overwrite=T)
# 
# #----------------------- 3.1.1. Get average distance to edge -------------------
# #patch distances
# df_SnS_dist <- landscapemetrics::lsm_p_enn(s_Habitat)
# df_conn_score <- df_SnS_dist %>% group_by(layer) %>% 
#   summarise(mean_distance=mean(value),median_distance=median(value),min_distance=min(value),max_distance=max(value)) 
# 
# df_conn_score_gfw <- df_conn_score %>% 
#   mutate(ref_value=df_conn_score$mean_distance[1], diff=mean_distance-ref_value, percentage=100-(diff*100/ref_value), info="GFW", Year=v_time_steps)
# 
# # write.csv(df_conn_score_gfw,file=paste0(outputFolder,sp,"_AreaScore_table.csv")) # table of summary values for distance to patches by year
# # 
# # img_Connectivity_TS <- ggplot(df_conn_score_gfw,aes(x=layer,y=percentage))+geom_line()
# # img_Connectivity_TS # time series for mean distance to patch
# 
# #---------------------- 3.1.2. Calculate areas ---------------------------------
# #create raster of areas by pixel
# r_areas <- terra::cellSize(s_HabitatArea[[1]],unit="km")
# 
# l_Suitable_area <- set_names(map(as.list(s_Habitat * r_areas),function(x) {
#   x<-x[!is.na(x)]
#   data.frame(Area=units::set_units(sum(x),"km2"))
# }),v_time_steps)
# 
# df_area_score <- l_Suitable_area %>% bind_rows(.id="Year")
# 
# df_area_score_gfw <-  df_area_score %>% dplyr::group_by(Year) %>% 
#   dplyr::mutate(ref_area=df_area_score$Area[1], diff=ref_area-Area, percentage=100-as.numeric(100*diff/ref_area), info="GFW")
# 
# # write.csv(df_area_score_gfw,file=paste0(outputFolder,sp,"_AreaScore_table.csv"))
# 
# # img_Area_TS <- ggplot( df_area_score_gfw %>% ungroup(),aes(x=as.numeric(Year),y=percentage))+geom_line()+xlab("Year")
# # img_Area_TS
# 
# #------------------------ 3.1.3. SHI -------------------------------------------
# df_SHI_gfw <- data.frame(HS=as.numeric(df_area_score_gfw$percentage),CS=df_conn_score_gfw$percentage)
# df_SHI_gfw <- df_SHI_gfw %>% mutate(SHI=(HS+CS)/2, info="GFW", Year=v_time_steps)

write_tsv(df_IUCN_habitat_cat,file=paste0(outputFolder,sp,"_SHI_table.tsv"))

# #-------------------------------------------------------------------------------
# #3.2 ESA data
# #-------------------------------------------------------------------------------
# cube_ESA_LC <- 
#   load_cube(stac_path = "https://io.biodiversite-quebec.ca/stac",
#             limit = 5000, 
#             collections = c("esacci-lc"), 
#             use.obs = F,
#             buffer.box = 0,
#             bbox = sf_ext_crs,
#             srs.cube = srs_cube,
#             spatial.res = 300,
#             t0 = paste0(t_0,"-01-01"),
#             t1 = paste0(t_n,"-12-31"),
#             temporal.res = paste0("P",(t_n-t_0)+1,"Y"), #Y year M month
#             resampling = "near")
# 
# 
# #to rescale data using proportions
# # lc_raster <- stacatalogue::load_prop_values_pc(stac_path =  "https://io.biodiversite-quebec.ca/stac",
# #                                                collections = c("esacci-lc"), 
# #                                                bbox = bbox,
# #                                                srs.cube = input$proj_to,
# #                                                t0 = input$t0,
# #                                                t1 = input$t1,
# #                                                limit = input$stac_limit,
# #                                                spatial.res = input$spatial_res, # in meters
# #                                                prop = input$proportion,
# #                                                prop.res = input$proportion_res,
# #                                                select_values = input$lc_classes,
# #                                                temporal.res =  temporal_res)
# 
# #select years according to time step
# cube_ESA_LC_time_steps <- cube_ESA_LC %>% gdalcubes::select_bands(paste0("esacci-lc-",v_time_steps)) 
# s_ESA_LC <- cube_to_raster(cube_ESA_LC,format = "terra") 
# s_ESA_LC_1km <- mask(terra::resample(s_ESA_LC,r_suitability_map, method = "mode"), r_suitability_map)
# s_ESA_LC <- s_ESA_LC_1km
# s_ESA_LC <- terra::classify(s_ESA_LC,rcl=matrix(c(NA,0),ncol=2))
# 
# #-----------------------------------------------
# #Load LC labels
# df_LC_label <- read.csv2("./LC_label.csv") 
# names(df_LC_label) <- c("ID","Label")
# df_LC_label <- df_LC_label %>% mutate(Suitability=0)
# df_LC_label$Suitability[df_LC_label$ID %in% LC_codes] <- 1
# 
# #******************************************************
# # df_LC_label$Suitability <- 0
# # MOL_codes_01 <- c(50,60,61,62,90,160)
# # df_LC_label$Suitability[df_LC_label$ID %in% MOL_codes_01] <- 1
# # MOL_codes_75 <- c(40,100)
# # df_LC_label$Suitability[df_LC_label$ID %in% MOL_codes_75] <- 0.75
# # MOL_codes_25 <- c(30,110)
# # df_LC_label$Suitability[df_LC_label$ID %in% MOL_codes_25] <- 0.25
# #******************************************************
# 
# #Asign LC raster legend
# s_ESA_LC_cat <- terra::rast(map(as.list(s_ESA_LC), function(x){
#   ras <- terra::as.factor(x)
#   ID <- levels(ras)[[1]]
#   rat <- data.frame(ID) %>% dplyr::left_join(df_LC_label %>% dplyr::select(-Suitability),by="ID")
#   levels(ras) <- rat
#   return(ras)
# }))
# names(s_ESA_LC_cat) <- names(s_ESA_LC)
# 
# s_LC_habitat <- terra::classify(s_ESA_LC_cat,df_LC_label %>% dplyr::select(-Label)) #substitute values in raster based on column from df_LC_label
# names(s_LC_habitat) <- gsub("esacc..lc.","suitable_",names(s_ESA_LC_cat))
# 
# s_HabitatArea <- mask(s_LC_habitat,r_suitability_map) # with background
# s_Habitat <- terra::classify(s_HabitatArea, matrix(c(0,NA),ncol=2,byrow=T)) # just forest
# names(s_Habitat) <- paste0("Habitat_",v_time_steps)
# r_HabitatFull <- terra::classify(terra::app(s_HabitatArea,fun=sum), matrix(c(-Inf,0,NA,1,Inf,1),ncol=3,byrow=T)) # complete area of forest through time range
# 
# writeRaster(s_Habitat,filename = paste0(outputFolder,sp,"_habitat_ESA.tif"),overwrite=T)
# 
# #----------------------- 3.2.1. Get average distance to edge -------------------
# #patch distances
# df_SnS_dist <- landscapemetrics::lsm_p_enn(s_Habitat)
# df_conn_score <- df_SnS_dist %>% group_by(layer) %>% 
#   summarise(mean_distance=mean(value),median_distance=median(value),min_distance=min(value),max_distance=max(value)) 
# 
# ggplot(df_SnS_dist,aes(x=factor(layer),y=value))+geom_boxplot()
# 
# df_conn_score_esa <- df_conn_score %>% 
#   mutate(ref_value=df_conn_score$mean_distance[1], diff=mean_distance-ref_value, percentage=100-(diff*100/ref_value), info="ESA", Year=v_time_steps)
# 
# img_Connectivity_TS <- ggplot(df_conn_score_esa,aes(x=Year,y=percentage))+geom_line()
# img_Connectivity_TS
# 
# #-------------------------- figure ----------------------------------------------
# #calculate differences by year
# s_suit_diff <- s_HabitatArea[[-1]] - s_HabitatArea[[-length(v_time_steps)]]
# s_suit_diff_mask <- terra::mask(s_suit_diff,r_HabitatFull)
# names(s_suit_diff_mask) <- paste("Change",v_time_steps[-length(v_time_steps)],v_time_steps[-1],sep="_")
# 
# #----------------------- 3.2.2. Calculate areas---------------------------------
# #create raster of areas by pixel
# r_areas <- terra::cellSize(s_HabitatArea[[1]],unit="km")
# 
# l_Suitable_area <- set_names(map(as.list(s_Habitat * r_areas),function(x) {
#   x<-x[!is.na(x)]
#   data.frame(Area=units::set_units(sum(x),"km2"))
# }),v_time_steps)
# 
# df_area_score <- l_Suitable_area %>% bind_rows(.id="Year")
# 
# df_area_score_esa <-  df_area_score %>% dplyr::group_by(Year) %>% 
#   dplyr::mutate(ref_area=df_area_score$Area[1], diff=ref_area-Area, percentage=as.numeric(Area*100/ref_area), info="ESA")
# 
# df_area_score_esa
# 
# img_Area_TS <- ggplot( df_area_score_esa %>% ungroup(),aes(x=as.numeric(Year),y=percentage))+geom_line()+xlab("Year")
# img_Area_TS
# 
# #SHI------------------------------------------------------
# df_SHI_esa <- data.frame(HS=as.numeric(df_area_score_esa$percentage),CS=df_conn_score_esa$percentage)
# df_SHI_esa <- df_SHI_esa %>% mutate(SHI=(HS+CS)/2, info="ESA" , Year=v_time_steps)
# df_SHI_esa
# 
# #--------------------------------------------------------------------------------
# # 4. SAVE DATA TO COMPARE
# #--------------------------------------------------------------------------------
# # Area
# df_area_score_all <- rbind(df_area_score_gfw,df_area_score_esa,df_area_score_bnb)
# write.csv(df_area_score_all,file=paste0(outputFolder,sp,"_AreaScore_table.csv"))
# df_area_score_all
# 
# img_Area_TS_all <- ggplot( df_area_score_all %>% ungroup(),aes(x=as.numeric(Year),y=percentage,color=info))+
#   geom_line(lwd=1)+xlab("Year")+ylab("Area Score (%)")+theme_bw()+geom_hline(yintercept = 100, linetype="dotted",lwd=1)+
#   scale_color_d3(palette = "category10",name="")+theme(legend.position = "bottom")#+scale_y_continuous(limits=c(50,110))
# img_Area_TS_all
# 
# ggsave(paste0(outputFolder,sp,"_area_score_all.png"),img_Area_TS_all)
# 
# # Connectivity
# df_conn_score_all <- rbind(df_conn_score_gfw,df_conn_score_esa,df_conn_score_bnb)
# write.csv(df_conn_score_all,file=paste0(outputFolder,sp,"_ConnectivityScore_table.csv"))
# 
# img_Connectivity_TS_all <- ggplot(df_conn_score_all,aes(x=Year,y=percentage,color=info))+
#   geom_line(lwd=1)+theme_bw()+xlab("Year")+ylab("Connectivity Score (%)")+geom_hline(yintercept = 100, linetype="dotted",lwd=1)+
#   scale_color_d3(palette = "category10",name="")+theme(legend.position = "bottom")#+scale_y_continuous(limits=c(50,110))
# img_Connectivity_TS_all
# 
# ggsave(paste0(outputFolder,sp,"_connnect_score_all.png"),img_Connectivity_TS_all)
# 
# 
# # SHI
# df_SHI_all <- rbind(df_SHI_gfw,df_SHI_esa,df_SHI_bnb)
# 
# write.csv(df_SHI_all,file=paste0(outputFolder,sp,"_SHI_table.csv"))
# 
# img_SHI_all <- ggplot(df_SHI_all,aes(x=Year,y=SHI,color=info))+
#   geom_line(lwd=1)+theme_bw()+xlab("Year")+ylab("Species Habitat Score (%)")+geom_hline(yintercept = 100, linetype="dotted",lwd=1)+
#   scale_color_d3(palette = "category10",name="")+theme(legend.position = "bottom")#+scale_y_continuous(limits=c(50,110))
# img_SHI_all
# 
# ggsave(paste0(outputFolder,sp,"_species_habitat_score_all.png"),img_SHI_all)
# 
# 
# # temp <- df_SHI_all %>% filter(info!="BnB")
# # temp2 <- temp %>% group_by(Year) %>% summarise(mean_CS=mean(CS))
# # 
# # ggplot( temp2 %>% ungroup(),aes(x=as.numeric(Year),y=mean_CS))+geom_line()+xlab("Year")
# 
