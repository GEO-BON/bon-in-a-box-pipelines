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

source(file.path(path_script,"SHI/funFilterCube_range.R"), echo=TRUE)

# Parameters -------------------------------------------------------------------
# Define species
sp <- str_to_sentence(input$species)

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

# Define expert range maps
range_map_path <- ifelse(is.null(input$sf_range_map), NA,input$sf_range_map)

# Define area of interest, country or region
study_area_path <- ifelse(is.null(input$study_area), NA,input$study_area)
country_code <- ifelse(is.null(input$country_code), NA,input$country_code)
region <- ifelse(is.null(input$region), NA ,input$region)

# Size of buffer around study area
buff_size <- ifelse(is.null(input$buff_size), NA,input$buff_size)

# Buffer for elevation values
elev_buffer <- ifelse(is.null(input$elev_buffer), NA,input$elev_buffer)

# spatial resolution
spat_res <- ifelse(is.null(input$spat_res), 1000 ,input$spat_res)

# binary sdm
bin_sdm_path <- ifelse(is.null(input$sdm_bin), NA,input$sdm_bin)

#credentials
token <- Sys.getenv("IUCN_TOKEN")

# Step 1.1 - Get range map #filter by expert source missing ----------------------
if(!is.na(range_map_path)){
  sf_range_map <- st_read(range_map_path)
}else{stop("A range map is needed. Add a polygon or use the SDM pipeline to produce a map with the potential area for the species.")}

print("========== Step 1.1 - Expert range map successfully loaded ==========")

# Step 1.2 - Get bounding box cropped by country if needed -----------------------
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

print("========== Step 1.2 - Bounding box created ==========")

# Step 1.3 - Create raster and limit area by elevation ranges---------------------
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
  cube_STRM <-
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
  cube_STRM_range <- funFilterCube_range(cube_STRM, min = min_elev , max = max_elev) |> select_bands("data")
  # convert to raster
  r_STRM <<- terra::wrap(cube_STRM  |> st_as_stars() |> terra::rast())
  r_STRM_range <- cube_STRM_range  |> st_as_stars() |> terra::rast()
  
  # resample to raster of range map
  r_STRM_range_res <<- terra::wrap(terra::resample(r_STRM_range, r_range_map))
  r_range_map <<- terra::wrap(terra::mask(terra::crop(r_range_map,unwrap(r_STRM_range_res)),unwrap(r_STRM_range_res))) #Crop to range extent
}
)

print("========== Step 1.3 - Create base rasters and filter area by elevation ranges ==========")

# Step 1.4 - Crop by binary SDM-------------------------------------------------
print(file.path(path_script,bin_sdm_path))
if(!is.na(bin_sdm_path)){
  r_bin_sdm <- rast(file.path(path_script,bin_sdm_path))
}else{stop("A binary raster file is required for this step. Add file or use the SDM pipeline to produce a map with the potential area for the species.")}

if(!crs(r_bin_sdm)==crs(srs_cube)){
  r_bin_sdm <- terra::project(r_bin_sdm, srs_cube, method="near") 
}
r_bin_sdm_frame <- terra::crop(r_bin_sdm, r_frame)
r_bin_sdm_frame_res <- terra::resample(r_bin_sdm_frame,r_frame,method="near")
r_range_map <- terra::mask(unwrap(r_range_map),r_bin_sdm_frame_res,maskvalues=1,inverse=T)

r_range_map_path <- file.path(outputFolder, "r_range_map.tiff")
writeRaster(unwrap(r_range_map), r_range_map_path, overwrite=T, gdal=c("COMPRESS=DEFLATE"), filetype="COG")

# Outputing result to JSON -----------------------------------------------------
output <- list("r_range_map" = r_range_map_path )

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder, "output.json"))