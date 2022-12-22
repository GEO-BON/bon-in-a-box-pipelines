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
epsg_crs <- suppressWarnings(CRS(na.exclude(epsg$prj4[epsg$code==ref_system])[1]))
sf_crs <- st_crs(ref_system)
srs_cube <- paste0("EPSG:",ref_system)

#margin for elevation range
elev_margin <- input$elev_margin
#forest threshold for GFW
forest_threshold <- input$forest_threshold #USE MAP OF LIFE VALUES!!*****
#define country if the area of analysis will be restricted to a specific country
if(input$country_code== "") country_code <-  NULL else country_code <- input$country_code
if(input$region== "") region <-  NULL else region <- input$region

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

setwd(outputFolder)

#-------------------------------------------------------------------------------------------------------------------
#1. Species distribution range
#-------------------------------------------------------------------------------------------------------------------
#1.1 Load expert range maps-------------------------------------------------------------
df_IUCN_sheet <- rl_search(sp, key = token)$result
print(getwd())
#Get range map #filter by expert source missing
source_range_maps <- data.frame(expert_source=expert_source) |>
  mutate(function_name=case_when(
    expert_source=="IUCN"~ "get_iucn_range_map",
    expert_source=="MOL"~ "get_mol_range_map",
    expert_source=="QC" ~ "get_qc_range_map"),
    species_name= case_when(
      expert_source=="IUCN"~ sp,
      expert_source=="MOL"~ sp,
      expert_source=="QC" ~ paste0(sp,"_qc")
    ),
    species_path= case_when(
      expert_source=="IUCN"~ sp,
      expert_source=="MOL"~ paste0(sp,"_mol"),
      expert_source=="QC" ~ paste0(sp,"_qc")
    ))

with(source_range_maps, do.call(function_name,args = list(species_name=species_name)))
sf_range_map <- st_read(paste0(source_range_maps$species_path,'_range.gpkg'))

#get bounding box cropped by country if needed
if(!is.null(country_code)){
  ifelse(!is.null(region),
         sf_area_lim1 <<- gadm(country=country_code, level=1, path=tempdir()) %>% st_as_sf() %>% st_make_valid() %>% filter(NAME_1==region),
         sf_area_lim1 <<- gadm(country=country_code, level=0, path=tempdir()) %>% st_as_sf() %>% st_make_valid()
  )
  
  sf_area_lim1_crs <- sf_area_lim1 %>% st_transform(sf_crs)
  
  sf_area_lim2 <- sf_range_map %>% st_make_valid
  sf_area_lim2_crs <- sf_area_lim2 %>% st_transform(sf_crs)
  
  sf_area_lim <<- st_intersection(sf_area_lim2 %>% st_transform(st_crs(sf_area_lim1)),sf_area_lim1,dimension="polygon")
  sf_area_lim_crs <<- st_intersection(sf_area_lim2_crs,sf_area_lim1_crs,dimension="polygon") %>% st_make_valid() %>% 
    st_collection_extract("POLYGON")
  
  if(all(st_is_valid(sf_area_lim))){
    sf_ext <<- st_bbox(sf_area_lim %>% st_buffer(10))
    }else{
      sf::sf_use_s2(FALSE)
      sf_ext <<- st_bbox(sf_area_lim %>% st_buffer(0.0001))
    }
  
  if(all(st_is_valid(sf_area_lim_crs))){
    sf_ext_crs <<- st_bbox(sf_area_lim_crs %>% st_buffer(10))
  }else{
    sf::sf_use_s2(FALSE)
    sf_ext_crs <<- st_bbox(sf_area_lim_crs %>% st_buffer(0.0001))
  }

}else{
  sf_area_lim <<- sf_range_map
  sf_area_lim_crs <<- sf_area_lim %>% st_transform(sf_crs)
  sf_ext <<- st_bbox(sf_area_lim %>% st_buffer(10)) # st_make_grid(sf_range_map,n=1) %>% st_buffer(10)
  sf_ext_crs <<- st_bbox(sf_area_lim_crs %>% st_buffer(10))
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
    is.na(elevation_lower) ~ NA_real_,
    !is.na(elevation_lower) & as.numeric(elevation_lower) < elev_margin ~ 0,
    !is.na(elevation_lower) & as.numeric(elevation_lower) >= elev_margin ~ as.numeric(elevation_lower) - elev_margin),
  max_elev= case_when(
    is.na(elevation_upper) ~ NA_real_,
    !is.na(elevation_upper) ~ as.numeric(elevation_upper) + elev_margin),
  condition= case_when( #generate possible options according to availability of minimum and maximum elevation values
    is.na(min_elev)  & is.na(max_elev)  ~ 1, # when there is no data for elevation ranges
    !is.na(min_elev) & !is.na(max_elev) ~ 2, # when the elevation ranges are available
    !is.na(min_elev) & is.na(max_elev)  ~ 3, # when there is just data for the maximum elevation
    is.na(min_elev)  & !is.na(max_elev) ~ 4) # when there is just data for the minimum elevation
)

with(df_IUCN_sheet_condition, if(condition == 1){ # if no elevation values are provided then the suitability map stays the same
  r_suitability_map <<- terra::rast(r_suitability_map)
}else{ # at least one elevation range exists then create cube_STRM to filter according to elevation ranges
  # STRM from Copernicus
  cube_STRM <<-
    load_cube(stac_path = "https://planetarycomputer.microsoft.com/api/stac/v1/",
              limit = 1000,
              collections = c("cop-dem-glo-90"),
              bbox = sf_ext_crs,
              srs.cube = srs_cube,
              spatial.res = spat_res,
              temporal.res = "P1Y",
              t0 = "2021-01-01",
              t1 = "2021-12-31",
              resampling = "bilinear")
  if(condition == 2){ # if both values exist
    cube_STRM_range <<- cube_STRM |>
      gdalcubes::filter_pixel(paste0("data <=", max_elev)) |>
      gdalcubes::filter_pixel(paste0("data >= ", min_elev)) |> select_bands("data")
  }else{ # if only one value exist
    if(condition == 3){ # if just maximum elevation available filter by that
      cube_STRM_range <<- cube_STRM |>
        gdalcubes::filter_pixel(paste0("data <=", max_elev)) |> select_bands("data")
    }
    if(condition == 4){ # if just minimum elevation available filter by that
      cube_STRM_range <<- cube_STRM |>
        gdalcubes::filter_pixel(paste0("data >= ", min_elev)) |> select_bands("data")
    }
  }
  #convert to raster
  r_STRM_range <<- cube_STRM_range  |> st_as_stars() |> terra::rast()

  #resample to raster of SDM
  r_STRM_range_res <<- terra::resample(r_STRM_range, terra::rast(r_suitability_map))
  r_suitability_map <<- terra::mask(terra::crop(terra::rast(r_suitability_map),r_STRM_range_res),r_STRM_range_res) #Crop LC to suitability extent
}
)

print("Map of suitable area generated")

#2.2 Load habitat preferences---------------------------------------------
df_IUCN_habitat_cat <- rl_habitats(sp,key = token)$result

#Load table with land cover equivalences need to be updated with Jung et al
df_IUCN_to_LC_categories <- read.csv(file.path(path_script,"SHI","IUCN_to_LC_categories.csv"),colClasses = "character") # PENDING PUT 0.5 TO MARGINAL HABITATS
df_IUCN_habitat_LC_cat <- left_join(df_IUCN_habitat_cat,df_IUCN_to_LC_categories, by="code")
LC_codes <- as.numeric(unique(df_IUCN_habitat_LC_cat$ESA_cod))

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
            bbox = sf_ext_crs,
            srs.cube = srs_cube,
            spatial.res = spat_res,
            temporal.res = "P1Y",
            t0 = "2000-01-01",
            t1 = "2000-01-01",
            resampling = "bilinear")

cube_GFW_TC_range <- cube_GFW_TC |>
  gdalcubes::filter_pixel(paste0("data >=", forest_threshold)) |>#filter to forest threshold 0-100
  gdalcubes::apply_pixel(paste0("data/data")) # turn into a forest presence map

r_GFW_TC_range <- cube_to_raster(cube_GFW_TC_range , format="terra") # convert to raster format

r_suitability_map_rescaled <- terra::resample(r_suitability_map,r_GFW_TC_range,method="bilinear") #Adjust scale of suitability map
r_GFW_TC_range_mask <- r_GFW_TC_range |>
  terra::classify(rcl=matrix(c(NA,0),ncol=2,byrow=T)) |> # turn NA to 0
  terra::mask(r_suitability_map_rescaled) # crop to suitability map

print("Base forest layer downloaded")

# Download forest loss maps and create different layers for each year to remove from forest
s_obj <- stac("https://io.biodiversite-quebec.ca/stac/")

it_obj <- s_obj |>
  stac_search(collections = "gfw-lossyear",
              bbox = sf_ext) |>
  get_request()

st <- gdalcubes::stac_image_collection(it_obj$features, asset_names = c("data")) # create image collection

v <- cube_view(srs = srs_cube, extent = list(t0 = "2000-01-01", t1 = "2000-12-31", # create cube according to area of interest
                                             left = sf_ext_crs['xmin'], right =sf_ext_crs['xmax'],
                                             top = sf_ext_crs['ymax'], bottom =  sf_ext_crs['ymin']),
               dx=spat_res, dy=spat_res, dt="P1Y",
               resampling = "near") # TO CHANGE to proportions

times <- as.numeric(substr(v_time_steps[v_time_steps>2000],start=3,stop=4)) #get year of change by selected time step to mask map by year of change
l_r_year_loss <- map(times, function(x) {
  layer <- raster_cube(image_collection=st, view=v,
                       mask=image_mask("data", values = times[times<=x],invert=T)) # to remove it to the following years

  layer <- layer |>
    stars::st_as_stars() |>
    terra::rast()
  return(layer)
})

#add background and mask to suitable area
s_year_loss <- terra::classify(terra::rast(l_r_year_loss), rcl=matrix(c(NA,NA,0,1,Inf,1),ncol=3,byrow=T),include.lowest=T)
names(s_year_loss) <- paste0("Loss_",v_time_steps[v_time_steps>2000])
s_year_loss_mask <- terra::mask(s_year_loss,r_suitability_map_rescaled)

#update reference forest layer if t_0 different of 2000
if(t_0!=2000){
  r_GFW_TC_range_mask <- terra::classify(r_GFW_TC_range_mask - terra::subset(s_year_loss_mask,paste0("Loss_",t_0)),rcl=matrix(c(-1,0),ncol=2,byrow=T))
}

cube_GFW_gain <-
  load_cube(stac_path = "https://io.biodiversite-quebec.ca/stac",
            limit = 1000,
            collections = c("gfw-gain"),
            bbox = sf_ext_crs,
            srs.cube = srs_cube,
            spatial.res = spat_res,
            temporal.res = "P1Y",
            t0 = "2000-01-01",
            t1 = "2000-12-31",
            resampling = "near")

r_GFW_gain <- cube_to_raster(cube_GFW_gain %>%
                               stars::st_as_stars(), format="terra") # convert to raster format
r_GFW_gain_mask <- terra::classify(terra::mask(r_GFW_gain ,r_suitability_map_rescaled),matrix(c(0,NA),ncol=2,byrow = T))

#-------------------------- figure ----------------------------------------------
osm <- read_osm(sf_area_lim, ext=1.1)

s_year_loss_mask_plot <- terra::classify(s_year_loss_mask,matrix(c(0,NA),ncol=2,byrow=T)) # turn 0 to NA
s_year_loss_mask_plot <- terra::app(s_year_loss_mask_plot,sum)>0

img_map_habitat_changes <- tm_shape(osm) + tm_rgb()+
  tm_shape(r_GFW_TC_range_mask)+tm_raster(style="cat",alpha=0.5,palette = c("#0000FF00","blue"))+
  tm_shape(s_year_loss_mask_plot)+tm_raster(style="cat",palette = c("#FF000080"))+
  tm_shape(r_GFW_gain_mask)+tm_raster(style="cat",alpha=0.8,palette = c("#FFFF0080"))+
  tm_shape(sf_area_lim)+tm_borders(lwd=0.5)+
  tm_compass()+tm_scale_bar()+tm_legend(show=F)

print("Map of changes in suitable area generated")

img_SHI_time_period_path <- file.path(outputFolder,paste0(sp,"_GFW_change.png"))
tmap_save(img_map_habitat_changes, img_SHI_time_period_path )

#create layers of forest removing loss by year
s_HabitatArea <- terra::classify(r_GFW_TC_range_mask-s_year_loss_mask , rcl=matrix(c(-1,0),ncol=2))
s_HabitatArea <- c(r_GFW_TC_range_mask, s_HabitatArea)
names(s_HabitatArea) <- paste0("Habitat_",v_time_steps)

s_Habitat <- terra::classify(s_HabitatArea , rcl=matrix(c(0,NA),ncol=2))
r_habitat_by_year_path <- file.path(outputFolder,paste0(sp,"_habitat_GFW.tif"))
writeRaster(s_Habitat,filename = r_habitat_by_year_path,overwrite=T)

#----------------------- 3.1.1. Get average distance to edge -------------------
#patch distances
df_SnS_dist <- landscapemetrics::lsm_p_enn(s_Habitat) #same as landscapemetrics::lsm_l_enn_mn(s_Habitat)
df_conn_score <- df_SnS_dist %>% group_by(layer) %>%
  summarise(mean_distance=mean(value),median_distance=median(value),min_distance=min(value),max_distance=max(value))

df_conn_score_gfw <- df_conn_score %>%
  mutate(ref_value=df_conn_score$mean_distance[1], diff=mean_distance-ref_value, percentage=100-(diff*100/ref_value), info="GFW", Year=v_time_steps)

print("Connectivity Score generated")

#---------------------- 3.1.2. Calculate areas ---------------------------------
#create raster of areas by pixel
r_areas <- terra::cellSize(s_HabitatArea[[1]],unit="km")

l_suitable_area <- set_names(map(as.list(s_Habitat * r_areas),function(x) {
  x<-x[!is.na(x)]
  data.frame(Area=units::set_units(sum(x),"km2"))
}),v_time_steps)

df_area_score <- l_suitable_area %>% bind_rows(.id="Year") # almost same as landscapemetrics::lsm_p_area(s_Habitat) but ?? units

df_area_score_gfw <-  df_area_score %>% dplyr::group_by(Year) %>%
  dplyr::mutate(ref_area=df_area_score$Area[1], diff=ref_area-Area, percentage=100-as.numeric(100*diff/ref_area), info="GFW")

print("Habitat Score generated")
# 
# # write.csv(df_area_score_gfw,file=paste0(outputFolder,sp,"_AreaScore_table.csv"))
# 
# # img_Area_TS <- ggplot( df_area_score_gfw %>% ungroup(),aes(x=as.numeric(Year),y=percentage))+geom_line()+xlab("Year")
# # img_Area_TS
# 
#------------------------ 3.1.3. SHI -------------------------------------------
df_SHI_gfw <- data.frame(HS=as.numeric(df_area_score_gfw$percentage),CS=df_conn_score_gfw$percentage)
df_SHI_gfw <- df_SHI_gfw %>% mutate(SHI=(HS+CS)/2, info="GFW", Year=v_time_steps)

df_SHI_path <- file.path(outputFolder,paste0(sp,"_SHI_table.tsv"))
write_tsv(df_SHI_gfw,file= df_SHI_path)

print("Species Habitat Index generated")

df_SHI_gfw_tidy <- df_SHI_gfw %>% pivot_longer(c("HS","CS","SHI"),names_to = "Index", values_to = "Value")

img_SHI_timeseries <- ggplot(df_SHI_gfw_tidy , aes(x=Year,y=Value,col=Index))+geom_line()+
  theme_bw()+ylab("Connectivity Score (CS), Habitat Score (HS), SHI")

img_SHI_timeseries_path <- file.path(outputFolder,paste0(sp,"_SHI_timeseries.png"))
ggsave(img_SHI_timeseries_path,img_SHI_timeseries,dpi = 300)

# Outputing result to JSON
output <- list("img_shi_time_period" = img_SHI_time_period_path,
               "df_shi" = df_SHI_path ,
               "r_habitat_by_year" = r_habitat_by_year_path,
               "img_shi_timeseries" = img_SHI_timeseries_path)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder, "output.json"))
