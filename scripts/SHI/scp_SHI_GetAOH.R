#-------------------------------------------------------------------------------
# This script produces the base maps for the area of interest, based on the data for the species
#-------------------------------------------------------------------------------
# Script location can be used to access other scripts
print(Sys.getenv("SCRIPT_LOCATION"))
options(timeout = max(60000000, getOption("timeout")))

packages <- c("rjson","remotes","dplyr","tidyr","purrr","terra","stars","sf",
              "geodata","gdalcubes","stacatalogue","rredlist","stringr")

if (!"gdalcubes" %in% installed.packages()[,"Package"]) remotes::install_git("https://github.com/appelmar/gdalcubes_R.git", update="never")
if (!"stacatalogue" %in% installed.packages()[,"Package"]) remotes::install_git("https://github.com/ReseauBiodiversiteQuebec/stac-catalogue", update="never", quiet=T)

new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

lapply(packages,require,character.only=T)

path_script <- Sys.getenv("SCRIPT_LOCATION")

input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

source(file.path(path_script,"SHI/funGet_range_maps.R"), echo=TRUE)
source(file.path(path_script,"SHI/funFilterCube_range.R"), echo=TRUE)

# Parameters -------------------------------------------------------------------
# Define species
sp <- str_to_sentence(input$species)

# Define source of expert range maps
expert_source <- input$expert_source

# Define area of interest, country or region
study_area_path <- ifelse(is.null(input$study_area), NA,input$study_area)
country_code <- ifelse(is.null(input$country_code), NA,input$country_code)
region <- ifelse(is.null(input$region), NA ,input$region)

r_sp_sdm_path <- ifelse(is.null(input$sdm), NA,input$study_area)

# Define SRS
srs <- input$srs
check_srs <- grepl("^[[:digit:]]+$",srs)
sf_srs  <-  if(check_srs) st_crs(as.numeric(srs)) else  st_crs(srs) # converts to numeric in case SRID is used
srs_cube <- suppressWarnings(if(check_srs){
  authorities <- c("EPSG","ESRI","IAU2000","SR-ORG")
  auth_srid <- paste(authorities,srs,sep=":")
  auth_srid_test <- map_lgl(auth_srid, ~ !"try-error" %in% class(try(st_crs(.x),silent=TRUE)))
  if(sum(auth_srid_test)!=1) print("--- Please specify authority name or provide description of the SRS ---") else auth_srid[auth_srid_test] 
}else srs )# paste Authority in case SRID is used 

# Size of buffer around study area
buff_size <- ifelse(is.null(input$buff_size), NA,input$study_area)

# Buffer for elevation values
elev_buffer <- ifelse(is.null(input$elev_buffer), NA,input$elev_buffer)

# spatial resolution
spat_res <- ifelse(is.null(input$spat_res), 1000 ,input$spat_res)

#credentials
token <- Sys.getenv("IUCN_TOKEN")

# Step 1 - Get range map #filter by expert source missing ----------------------
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

print("========== Step 1 - Expert range map successfully loaded ==========")

# Step 2 - Get bounding box cropped by country if needed -----------------------
study_area <- data.frame(study_area_path= study_area_path ,
                         country_code = country_code ,
                         region = region ) |>
  dplyr::mutate(option=case_when(
    is.na(study_area_path) & is.na(country_code) ~ 1,
    !is.na(study_area_path) ~  2,
    !is.na(country_code) & is.na(region) ~  3,
    !is.na(country_code) & !is.na(region) ~ 4
  ))

if(study_area$option == 1){
  sf_area_lim <- sf_range_map
  sf_area_lim_srs <- sf_area_lim |> st_transform(sf_srs)
}else{
  if(study_area$option == 2){
    sf_area_lim1 <- st_read(study_area_path)
  }
  if(study_area$option == 3){
    sf_area_lim1 <- gadm(country=country_code, level=0, path=tempdir()) |> st_as_sf() |> st_make_valid()
  }
  if(study_area$option == 4){
    sf_area_lim1 <- gadm(country=country_code, level=1, path=tempdir()) |> st_as_sf() |> st_make_valid() |> filter(NAME_1==region)
  }
  sf_area_lim1_srs <- sf_area_lim1 |> st_transform(sf_srs)
  
  sf_area_lim2 <- sf_range_map |> st_make_valid() |> st_transform(st_crs(sf_area_lim1))
  sf_area_lim2_srs <- sf_area_lim2 |> st_transform(sf_srs)
  
  sf_area_lim <- st_intersection(sf_area_lim2,sf_area_lim1,dimension="polygon") |> st_make_valid()
  sf_area_lim_srs <- st_intersection(sf_area_lim2_srs,sf_area_lim1_srs,dimension="polygon") |> st_make_valid()
}

# define buffer size 
if(is.na(buff_size)){
  sf_bbox_aoh <- sf_area_lim |> st_bbox() |> st_as_sfc()
  buff_size <- round(sqrt( sf_bbox_aoh |> st_area())/2)
}else{
  buff_size <- buff_size
}

# get bounding box for the complete area projected and non projected
suppressWarnings({
  if(!is.null(st_crs(sf_area_lim_srs)$units)){
  sf_ext_srs <<- st_bbox(sf_area_lim_srs |> st_buffer(buff_size))
  }else{
  sf::sf_use_s2(FALSE)
  sf_ext_srs <<- st_bbox(sf_area_lim_srs |> st_buffer(buff_size*0.00001)) # approximate value from degrees to m
  print("--- Buffer defined for spherical geometry ---")
  }
})
print(sf_ext_srs)

#Create raster
sf_bbox <- st_as_sfc(sf_ext_srs)
#st_write(sf_bbox,file.path("./Connectivity/layers_for_omniscape",sp,"st_bbox.gpkg"),append=F)

print("========== Step 2 - Bounding box created ==========")

# Step 3 - Create raster -------------------------------------------------------
# Bounding box raster
r_frame <- rast(terra::ext(sf_ext_srs),resolution=spat_res)
crs(r_frame) <- srs_cube
values(r_frame) <- 1
#writeRaster(r_frame,file.path("./Connectivity/layers_for_omniscape",sp,"./r_frame.tif"),overwrite=T, gdal=c("COMPRESS=DEFLATE"), filetype="COG")

# Mask to study area
r_range_map <- terra::mask(r_frame,vect(sf_area_lim_srs))

# Load elevation preferences
df_IUCN_sheet <- rredlist::rl_search(sp, key = token)$result

df_IUCN_sheet_condition <- df_IUCN_sheet |> dplyr::mutate(
  min_elev= case_when( #evaluate if elevation ranges exist and add margin if included
    is.na(elevation_lower) ~ NA_real_,
    !is.na(elevation_lower) & (as.numeric(elevation_lower) < elev_buffer)  ~ 0,
    !is.na(elevation_lower) & (as.numeric(elevation_lower) >= elev_buffer) ~ as.numeric(elevation_lower) - elev_buffer),
  max_elev= case_when(
    is.na(elevation_upper) ~ NA_real_,
    !is.na(elevation_upper) ~ as.numeric(elevation_upper) + elev_buffer)
)

print(df_IUCN_sheet_condition |> select(elevation_lower, elevation_upper))

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
  r_STRM <<- cube_STRM  |> st_as_stars() |> terra::rast()
  cube_STRM_range <<- funFilterCube_range(cube_STRM, min = min_elev , max = max_elev) |> select_bands("data")
  # convert to raster
  r_STRM_range <<- cube_STRM_range  |> st_as_stars() |> terra::rast()
  
  # resample to raster of SDM
  r_STRM_range_res <<- terra::resample(r_STRM_range, r_range_map)
  r_range_map <<- terra::mask(terra::crop(r_range_map,r_STRM_range_res),r_STRM_range_res) #Crop LC to range extent
}
)

print("========== Step 3 - Create base rasters ==========")

r_range_map_path <- file.path(outputFolder, "r_range_map.tiff")
writeRaster(r_range_map, r_range_map_path, overwrite=T, gdal=c("COMPRESS=DEFLATE"), filetype="COG")
#writeRaster(r_STRM,file.path("./Connectivity/layers_for_omniscape",sp,"r_STRM.tif"),overwrite=T, gdal=c("COMPRESS=DEFLATE"), filetype="COG")
#writeRaster(r_STRM_range_res,file.path("./Connectivity/layers_for_omniscape",sp,"r_STRM_range_res.tif"),overwrite=T, gdal=c("COMPRESS=DEFLATE"), filetype="COG")


# Outputing result to JSON -----------------------------------------------------
output <- list("r_range_map" = r_range_map_path )

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder, "output.json"))