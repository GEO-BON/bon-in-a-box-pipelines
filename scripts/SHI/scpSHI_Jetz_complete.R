#This script joins different sections to calculate the species habitat index 
#according to what is understood from the methodology Walter Jetz's team uses 
#for this calculation and compares the use of different land cover sources
#-------------------------------------------------------------------------------------------------------------------
#0. Load libraries and define Parameters
#-------------------------------------------------------------------------------------------------------------------
# Script location can be used to access other scripts
print(Sys.getenv("SCRIPT_LOCATION"))
options(timeout = max(60000000, getOption("timeout")))

## Install required packages
packages <- c("devtools","rlang","dplyr","tidyr","ggplot2","remotes","purrr","tmap","raster","ggsci","readr",
              "rgbif","rgdal","sf","httr","jsonlite","landscapemetrics","rjson","stars","geodata","rredlist",
              "stacatalogue","gdalcubes","rstac","RColorBrewer","RCurl","tmaptools","gdalUtilities","OpenStreetMap")

if (!"gdalcubes" %in% installed.packages()[,"Package"]) remotes::install_git("https://github.com/appelmar/gdalcubes_R.git", update="never")
if (!"stacatalogue" %in% installed.packages()[,"Package"]) remotes::install_git("https://github.com/ReseauBiodiversiteQuebec/stac-catalogue", update="never", quiet=T)
# 
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

lapply(packages,require,character.only=T)

path_script <- Sys.getenv("SCRIPT_LOCATION")
source(file.path(path_script,"SHI/funGet_range_maps.R"), echo=TRUE)
source(file.path(path_script,"SHI/funFilterCube_range.R"), echo=TRUE)

input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

#Define species
sp <- input$species

#Define SRS
srs <- input$srs
check_srs <- grepl("^[[:digit:]]+$",srs)
sf_srs  <-  if(check_srs) st_crs(as.numeric(srs)) else  st_crs(srs) # converts to numeric in case SRID is used
srs_cube <- suppressWarnings(if(check_srs){
  authorities <- c("EPSG","ESRI","IAU2000","SR-ORG")
  auth_srid <- paste(authorities,srs,sep=":")
  auth_srid_test <- map_lgl(auth_srid, ~ !"try-error" %in% class(try(st_crs(.x),silent=TRUE)))
  if(sum(auth_srid_test)!=1) print("--- Please specify authority name or provide description of the SRS ---") else auth_srid[auth_srid_test] 
}else srs )# paste Authority in case SRID is used 

#margin for elevation range
elev_buffer <- input$elev_buffer
#spatial resolution
spat_res <- input$spat_res

#define country if the area of analysis will be restricted to a specific country
country_code <- ifelse(is.null(input$country_code), NA,input$country_code)
region <- ifelse(is.null(input$region), NA ,input$region)

#Define source of expert range maps
expert_source <- input$expert_source
#forest threshold for GFW (level of forest for the species)
min_forest <- ifelse(is.null(input$min_forest), NA,input$min_forest)
max_forest <- ifelse(is.null(input$max_forest), NA,input$max_forest)

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

# Set output folder as working directory which has permissions to save files
setwd(outputFolder)

#-------------------------------------------------------------------------------------------------------------------
#1. Species distribution range
#-------------------------------------------------------------------------------------------------------------------
#1.1 Load expert range maps-------------------------------------------------------------
df_IUCN_sheet <- rredlist::rl_search(sp, key = token)$result
print(getwd())
#Get range map #filter by expert source missing
source_range_maps <- data.frame(expert_source=expert_source ,
                                species_name = sp) |>
  dplyr::mutate(function_name=case_when(
    expert_source=="IUCN"~ "get_iucn_range_map",
    expert_source=="MOL"~ "get_mol_range_map",
    expert_source=="QC" ~ "get_qc_range_map"
    ),
    species_path= case_when(
      expert_source=="IUCN"~ sp,
      expert_source=="MOL"~ paste0(sp,"_mol"),
      expert_source=="QC" ~ paste0(sp,"_qc")
    ))

with(source_range_maps, do.call(function_name,args = list(species_name=species_name)))
sf_range_map <- st_read(paste0(source_range_maps$species_path,'_range.gpkg'))

print("========== Expert range map successfully loaded ==========")

#get bounding box cropped by country if needed
suppressWarnings({
if(!is.na(country_code)){
  sf_area_lim1 <<- if(!is.na(region)){
    gadm(country=country_code, level=1, path=tempdir()) |> st_as_sf() |> st_make_valid() |> filter(NAME_1==region)
  } else gadm(country=country_code, level=0, path=tempdir()) |> st_as_sf() |> st_make_valid()
  
  sf_area_lim1_srs <- sf_area_lim1 |> st_transform(sf_srs)
  
  sf_area_lim2 <- sf_range_map |> st_make_valid() |> st_transform(st_crs(sf_area_lim1))
  sf_area_lim2_srs <- sf_area_lim2 |> st_transform(sf_srs)
  
  sf_area_lim <<- st_intersection(sf_area_lim2,sf_area_lim1,dimension="polygon") |> st_make_valid() |>
    st_collection_extract("POLYGON")
  sf_area_lim_srs <<- st_intersection(sf_area_lim2_srs,sf_area_lim1_srs,dimension="polygon") |> st_make_valid() |> 
    st_collection_extract("POLYGON")
  
  if(!is.null(st_crs(sf_area_lim_srs)$units)){
    sf_ext_srs <<- st_bbox(sf_area_lim_srs |> st_buffer(spat_res*10))
  }else{
    sf::sf_use_s2(FALSE)
    sf_ext_srs <<- st_bbox(sf_area_lim_srs |> st_buffer(spat_res*0.00001*10))
    print("--- Buffer defined for spherical geometry ---")
  }
  print(sf_ext_srs)

}else{
  sf_area_lim <<- sf_range_map
  sf_area_lim_srs <<- sf_area_lim |> st_transform(sf_srs)
  
  if(!is.null(st_crs(sf_area_lim_srs)$units)){
    sf_ext_srs <<- st_bbox(sf_area_lim_srs |> st_buffer(spat_res*10))
  }else{
    sf::sf_use_s2(FALSE)
    sf_ext_srs <<- st_bbox(sf_area_lim_srs |> st_buffer(spat_res*0.00001*10))
  }
  print(sf_ext_srs)
}
})

#1.4 Final range----------------------------------------------------------------
#Create raster
r_frame <- rast(terra::ext(sf_ext_srs),resolution=spat_res)
crs(r_frame) <- srs_cube
values(r_frame) <- 1
r_range_map <- terra::mask(r_frame,vect(as(sf_area_lim_srs,"Spatial")))

#-------------------------------------------------------------------------------------------------------------------
#2. Habitat Preferences
#-------------------------------------------------------------------------------------------------------------------
#2.1 Load elevation preferences---------------------------------------------
df_IUCN_sheet_condition <- df_IUCN_sheet |> dplyr::mutate(
  min_elev= case_when( #evaluate if elevation ranges exist and add margin if included
    is.na(elevation_lower) ~ NA_real_,
    !is.na(elevation_lower) & (as.numeric(elevation_lower) < elev_buffer)  ~ 0,
    !is.na(elevation_lower) & (as.numeric(elevation_lower) >= elev_buffer) ~ as.numeric(elevation_lower) - elev_buffer),
  max_elev= case_when(
    is.na(elevation_upper) ~ NA_real_,
    !is.na(elevation_upper) ~ as.numeric(elevation_upper) + elev_buffer)
)

with(df_IUCN_sheet_condition, if(is.na(min_elev)  & is.na(max_elev)){ # if no elevation values are provided then the range map stays the same
  r_range_map <<- r_range_map
}else{ # at least one elevation range exists then create cube_STRM to filter according to elevation ranges
  # STRM from Copernicus
  cube_STRM <<-
    load_cube(stac_path = "https://planetarycomputer.microsoft.com/api/stac/v1/",
              limit = 1000,
              collections = c("cop-dem-glo-90"),
              bbox = sf_ext_srs,
              srs.cube = srs_cube,
              spatial.res = spat_res,
              temporal.res = "P1Y",
              t0 = "2021-01-01",
              t1 = "2021-12-31",
              resampling = "bilinear")
  cube_STRM_range <<- funFilterCube_range(cube_STRM, min = min_elev , max = max_elev) |> select_bands("data")
  #convert to raster
  r_STRM_range <<- cube_STRM_range  |> st_as_stars() |> terra::rast()

  #resample to raster of SDM
  r_STRM_range_res <<- terra::resample(r_STRM_range, r_range_map)
  r_range_map <<- terra::mask(terra::crop(r_range_map,r_STRM_range_res),r_STRM_range_res) #Crop LC to range extent
}
)

print("========== Map of suitable area generated ==========")

#2.2 Load habitat preferences---------------------------------------------
# df_IUCN_habitat_cat <- rl_habitats(sp,key = token)$result
# 
# #Load table with land cover equivalences need to be updated with Jung et al
# df_IUCN_to_LC_categories <- read.csv(file.path(path_script,"SHI","IUCN_to_LC_categories.csv"),colClasses = "character") # PENDING PUT 0.5 TO MARGINAL HABITATS
# df_IUCN_habitat_LC_cat <- left_join(df_IUCN_habitat_cat,df_IUCN_to_LC_categories, by="code")
# LC_codes <- as.numeric(unique(df_IUCN_habitat_LC_cat$ESA_cod))

#2.3 Hydrological features------------------------------------------------------


#-------------------------------------------------------------------------------------------------------------------
#3. Land Cover Values
#-------------------------------------------------------------------------------------------------------------------
#3.1 GFW data-------------------------------------------------------------------
#forest base map
cube_GFW_TC <-
  load_cube(stac_path = "https://io.biodiversite-quebec.ca/stac/",
            limit = 1000,
            collections = c("gfw-treecover2000"),
            bbox = sf_ext_srs,
            srs.cube = srs_cube,
            spatial.res = spat_res,
            temporal.res = "P1Y",
            t0 = "2000-01-01",
            t1 = "2000-12-31",
            resampling = "bilinear")

if(is.na(min_forest)  & is.na(max_forest)){
  print("--- At least one level of tree cover percentage is needed ---")
}else{
  cube_GFW_TC_threshold <<- funFilterCube_range(cube_GFW_TC,min=min_forest,max=max_forest,value=FALSE)
}
r_GFW_TC_threshold <- cube_to_raster(cube_GFW_TC_threshold , format="terra") # convert to raster format

r_range_map_rescaled <- terra::resample(r_range_map,r_GFW_TC_threshold,method="mode") #Adjust scale of range map
r_GFW_TC_threshold_mask <- r_GFW_TC_threshold |>
  terra::classify(rcl=cbind(NA,0)) |> # turn NA to 0
  terra::mask(r_range_map_rescaled) # mask to range map

print("========== Base forest layer downloaded ==========")

# Download forest loss maps and create different layers for each year to remove from forest
cube_GFW_loss <-
  load_cube(stac_path = "https://io.biodiversite-quebec.ca/stac/",
            limit = 1000,
            collections = c("gfw-lossyear"),
            bbox = sf_ext_srs,
            srs.cube = srs_cube,
            spatial.res = spat_res,
            temporal.res = "P1Y",
            t0 = "2000-01-01",
            t1 = "2000-12-31",
            resampling = "mode", 
            aggregation = "first")

times <- as.numeric(substr(v_time_steps[v_time_steps>2000],start=3,stop=4))

l_year_loss <- map(times, ~ funFilterCube_range(cube = cube_GFW_loss, max=.x, type_max=1, min=1, type_min=1, value=FALSE))
l_r_year_loss <- map(l_year_loss, cube_to_raster, format="terra")
s_year_loss <- rast(l_r_year_loss) |> terra::classify(rcl=cbind(NA,0))
names(s_year_loss) <- paste0("Loss_",v_time_steps[v_time_steps>t_0])

s_year_loss_mask <- terra::mask(s_year_loss,r_GFW_TC_threshold_mask, maskvalues=1, inverse=TRUE)

#if t_0 different of 2000 update reference forest layer "r_GFW_TC_threshold_mask" 
if(t_0!=2000){
  r_GFW_TC_threshold_mask <- terra::classify(r_GFW_TC_threshold_mask - terra::subset(s_year_loss_mask,paste0("Loss_",t_0)),rcl=cbind(-1,0))
}

#-------------------------- figure ----------------------------------------------
r_year_loss_mask_plot <- terra::classify(s_year_loss_mask[[length(l_r_year_loss)]],rcl=cbind(0,NA)) # turn 0 to NA

cube_GFW_gain <-
  load_cube(stac_path = "https://io.biodiversite-quebec.ca/stac",
            limit = 1000,
            collections = c("gfw-gain"),
            bbox = sf_ext_srs,
            srs.cube = srs_cube,
            spatial.res = spat_res,
            temporal.res = "P1Y",
            t0 = "2000-01-01",
            t1 = "2000-12-31",
            resampling = "near")

r_GFW_gain <- cube_to_raster(cube_GFW_gain , format="terra") # convert to raster format
r_GFW_gain_mask <- terra::classify(terra::mask(r_GFW_gain ,r_range_map_rescaled),rcl=cbind(0,NA))

osm <- read_osm(sf_area_lim, ext=1.1)

img_map_habitat_changes <- tm_shape(osm) + tm_rgb()+
  tm_shape(r_GFW_TC_threshold_mask)+tm_raster(style="cat",alpha=0.5,palette = c("#0000FF00","blue"), legend.show = FALSE)+
  tm_shape(r_year_loss_mask_plot)+tm_raster(style="cat",palette = c("red"), legend.show = FALSE)+
  tm_shape(r_GFW_gain_mask)+tm_raster(style="cat",alpha=0.8,palette = c("yellow"), legend.show = FALSE)+
  tm_shape(sf_area_lim)+tm_borders(lwd=0.5)+
  tm_compass()+tm_scale_bar()+tm_layout(legend.bg.color = "white",legend.bg.alpha = 0.5,legend.outside = F)+
  tm_add_legend(labels=c("No change","Loss","Gain"),col=c("blue","red","yellow"),title="Suitable Habitat")

print("========== Map of changes in suitable area generated ==========")

img_SHI_time_period_path <- file.path(outputFolder,paste0(sp,"_GFW_change.png"))
tmap_save(img_map_habitat_changes, img_SHI_time_period_path )

#create layers of forest removing loss by year
s_HabitatArea0 <- r_GFW_TC_threshold_mask-s_year_loss_mask
s_HabitatArea <- if(t_0!=2000)  s_HabitatArea0 else c(r_GFW_TC_threshold_mask, s_HabitatArea0) 
rm(s_HabitatArea0)
names(s_HabitatArea) <- paste0("Habitat_",v_time_steps)

s_Habitat <- terra::classify(s_HabitatArea , rcl=cbind(0,NA))
r_habitat_by_tstep_path <- file.path(outputFolder, paste0(paste(sub(" ", "_", sp),"GFW",names(s_Habitat),sep="_"), ".tiff"))
map2(as.list(s_Habitat), r_habitat_by_tstep_path, ~terra::writeRaster(.x,filename=.y,overwrite=T, gdal=c("COMPRESS=DEFLATE"), filetype="COG"))
print(list.files(outputFolder, pattern = "Habitat", full.names = T))

#----------------------- 3.1.1. Get average distance to edge -------------------
#patch distances
df_SnS_dist <- landscapemetrics::lsm_p_enn(s_Habitat) #same as landscapemetrics::lsm_l_enn_mn(s_Habitat)
df_conn_score <- df_SnS_dist |> group_by(layer) |>
  summarise(mean_distance=mean(value),median_distance=median(value),min_distance=min(value),max_distance=max(value))

df_conn_score_gfw <- df_conn_score |>
  dplyr::mutate(ref_value=df_conn_score$mean_distance[1], diff=mean_distance-ref_value, percentage=100-(diff*100/ref_value), info="GFW", Year=v_time_steps)

print("========== Connectivity Score generated ==========")

#---------------------- 3.1.2. Calculate areas ---------------------------------
#create raster of areas by pixel
r_areas <- terra::cellSize(s_HabitatArea[[1]],unit="km")

l_suitable_area <- set_names(map(as.list(s_Habitat * r_areas),function(x) {
  x<-x[!is.na(x)]
  data.frame(Area=units::set_units(sum(x),"km2"))
}),v_time_steps)

df_area_score <- l_suitable_area |> bind_rows(.id="Year") # almost same as landscapemetrics::lsm_p_area(s_Habitat) but ?? units

df_area_score_gfw <-  df_area_score |> dplyr::group_by(Year) |>
  dplyr::mutate(ref_area=df_area_score$Area[1], diff=ref_area-Area, percentage=100-as.numeric(100*diff/ref_area), info="GFW")

print("========== Habitat Score generated ==========")

#------------------------ 3.1.3. SHI -------------------------------------------
df_SHI_gfw <- data.frame(HS=as.numeric(df_area_score_gfw$percentage),CS=df_conn_score_gfw$percentage)
df_SHI_gfw <- df_SHI_gfw |> dplyr::mutate(SHI=(HS+CS)/2, info="GFW", Year=v_time_steps)
df_SHI_gfw_tidy <- df_SHI_gfw |> pivot_longer(c("HS","CS","SHI"),names_to = "Index", values_to = "Value")

colnames(df_SHI_gfw) <- c("Habitat Score","Connectivity Score","Species Habitat Index","Source","Year")
df_SHI_path <- file.path(outputFolder,paste0(sp,"_SHI_table.tsv"))
write_tsv(df_SHI_gfw,file= df_SHI_path)

print("========== Species Habitat Index generated ==========")

img_SHI_timeseries <- ggplot(df_SHI_gfw_tidy , aes(x=Year,y=Value,col=Index))+geom_line()+
  theme_bw()+ylab("Connectivity Score (CS), Habitat Score (HS), SHI")

img_SHI_timeseries_path <- file.path(outputFolder,paste0(sp,"_SHI_timeseries.png"))
ggsave(img_SHI_timeseries_path,img_SHI_timeseries,dpi = 300)

# Outputing result to JSON
output <- list("img_shi_time_period" = img_SHI_time_period_path,
               "df_shi" = df_SHI_path ,
               "r_habitat_by_tstep" = r_habitat_by_tstep_path,
               "img_shi_timeseries" = img_SHI_timeseries_path)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder, "output.json"))
