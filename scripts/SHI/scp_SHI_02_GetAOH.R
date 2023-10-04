#-------------------------------------------------------------------------------
# This script produces the base maps for the area of interest, based on the data for the species
#-------------------------------------------------------------------------------
# Script location can be used to access other scripts
print(Sys.getenv("SCRIPT_LOCATION"))
options(timeout = max(60000000, getOption("timeout")))

packages <- c("rjson","remotes","dplyr","tidyr","purrr","terra","stars","sf","readr",
              "geodata","gdalcubes","stacatalogue","rredlist","stringr")

if (!"gdalcubes" %in% installed.packages()[,"Package"]) remotes::install_git("https://github.com/appelmar/gdalcubes_R.git")
if (!"stacatalogue" %in% installed.packages()[,"Package"]) remotes::install_git("https://github.com/ReseauBiodiversiteQuebec/stac-catalogue")

new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

lapply(packages,require,character.only=T)

path_script <- Sys.getenv("SCRIPT_LOCATION")

input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

source(file.path(path_script,"SHI/funFilterCube_range.R"), echo=TRUE)

# Parameters -------------------------------------------------------------------
# spatial resolution
spat_res <- ifelse(is.null(input$spat_res), 1000 ,input$spat_res)

# Define SRS
srs <- input$srs
check_srs <- grepl("^[[:digit:]]+$",srs)
sf_srs  <-  if(check_srs) st_crs(as.numeric(srs)) else  st_crs(srs) # converts to numeric in case SRID is used
srs_cube <- suppressWarnings(if(check_srs){
  authorities <- c("EPSG","ESRI","IAU2000","SR-ORG")
  auth_srid <- paste(authorities,srs,sep=":")
  auth_srid_test <- map_lgl(auth_srid, ~ !"try-error" %in% class(suppressWarnings(try(st_crs(.x),silent=TRUE))))
  if(sum(auth_srid_test)!=1) print("--- Please specify authority name or provide description of the SRS ---") else auth_srid[auth_srid_test] 
}else srs )# paste Authority in case SRID is used 

# Define area of interest, country or region
study_area_opt <- input$study_area_opt
study_area_path <- ifelse(is.null(input$study_area), NA,input$study_area)
country_code <- ifelse(is.null(input$country_code), NA,input$country_code)
region <- ifelse(is.null(input$region), NA ,input$region)

# Size of buffer around study area
buff_size <- ifelse(is.null(input$buff_size), NA,input$buff_size)

# Define species
sp <- str_to_sentence(input$species)

# Range map option
range_map_type <- ifelse(is.null(input$range_map_type), NA,input$range_map_type)
# Define expert range maps
sf_range_map_path <- if(is.null(input$sf_range_map)){NA}else{input$sf_range_map}
r_range_map_path <- if(is.null(input$r_range_map)){NA}else{input$r_range_map}

# Elevation_filter
elevation_filter <- ifelse(input$elevation_filter=="Yes", 1,NA)
# Buffer for elevation values
elev_buffer <- ifelse(is.null(input$elev_buffer), NA,input$elev_buffer)

#credentials
token <- Sys.getenv("IUCN_TOKEN")

#-------------------------------------------------------------------------------
# Step 1 - Get study area
#-------------------------------------------------------------------------------
study_area <- data.frame(study_area_path= study_area_path ,
                         country_code = country_code ,
                         region = region ) |>
  dplyr::mutate(option=case_when(
    !is.na(study_area_path) ~  1,
    !is.na(country_code) & is.na(region) ~  2,
    !is.na(country_code) & !is.na(region) ~ 3,
    is.na(study_area_path) & is.na(country_code) ~ 4,
  ))

study_area <- data.frame(text=study_area_opt,
                         study_area_path= study_area_path ,
                         country_code = country_code ,
                         region = region) |> 
  dplyr::mutate(option=case_when(
    study_area_opt == "Country" ~  1,
    study_area_opt == "Region in Country" ~  2,
    study_area_opt == "User defined" ~ 3,
    is.null(study_area_opt) ~ 4,
  ))

if(study_area$option == 1){
  sf_area_lim1 <- gadm(country=country_code, level=0, path=tempdir()) |> st_as_sf() |> st_make_valid() # country
}
if(study_area$option == 2){
  sf_area_lim1 <- gadm(country=country_code, level=1, path=tempdir()) |> st_as_sf() |> st_make_valid() |> filter(NAME_1==region) # region in a country
}
if(study_area$option == 3){
  sf_area_lim1 <- st_read(study_area_path) # user defined area
}
if(study_area$option == 4){
  print("A study area is required, please choose one of the options")
}


sf_area_lim1_srs <- sf_area_lim1 |> st_transform(sf_srs)
area_study_a <<- sf_area_lim1_srs |> st_area()


print("==================== Step 1 - Study area loaded =====================")

#-------------------------------------------------------------------------------
# Step 2 -  Get area of habitat
#-------------------------------------------------------------------------------
v_path_to_area_of_habitat <- c()
v_path_bbox_analysis <- c()
df_aoh_areas <- tibble()

for(i in 1:length(sp)){
  if (!dir.exists(file.path(outputFolder,sp[i]))){
    dir.create(file.path(outputFolder,sp[i]))
  }else{
    print("dir exists")
  }
  
  # Get range map---------------------------------------------------------------
  sf_range_map <<- st_read(sf_range_map_path[i])
  if(range_map_type=="Polygon"){
    sf_range_map <<- st_read(sf_range_map_path[i])
  }
  if(range_map_type=="Raster"){
    r_range_map <- rast(r_range_map_path[i])
    sf_range_map <<- as.polygons(r_range_map)
  }
  if(range_map_type=="Both"){
    sf_range_map <<- st_read(sf_range_map_path[i])
    r_range_map <- rast(r_range_map_path[i])
    r_range_map2 <- project(r_range_map, crs(sf_range_map), method="near")
    r_range_map2 <- mask(crop(r_range_map2, sf_range_map), sf_range_map)
    sf_range_map <<- as.polygons(ifel(r_range_map2==1,1,NA)) |> st_as_sf()
  }
  
  sf_area_lim2 <- sf_range_map |> st_make_valid() |> st_transform(st_crs(sf_area_lim1))
  sf_area_lim2_srs <- sf_area_lim2 |> st_transform(sf_srs)
  
  area_range_map <- sf_area_lim2_srs |> st_combine() |> st_combine() |> st_area()
  
  print("========== Step 2.1 - Expert range map successfully loaded ==========")
  
  # Intersect range map to study area-------------------------------------------
  # sf_area_lim <- st_intersection(sf_area_lim2,sf_area_lim1) |> 
  #   st_make_valid()
  sf_area_lim_srs <- st_intersection(sf_area_lim2_srs,sf_area_lim1_srs) |> 
    st_make_valid()
  
  print(sf_area_lim_srs)
  # define buffer size 
  if(is.na(buff_size)){
    # Buffer size for range map
    sf_bbox_aoh <- sf_area_lim_srs |> st_bbox() |> st_as_sfc()
    area_bbox <- sf_bbox_aoh |> st_area()
    buff_size <- round(sqrt(area_bbox)/2)
  }else{
    buff_size <- buff_size
  }
  
  # get bounding box for the complete area projected and non projected----------
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
  
  sf_bbox_analysis <- sf_ext_srs |> st_as_sfc()
  area_bbox_analysis <- sf_bbox_analysis |> st_area()
  
  v_path_bbox_analysis[i] <- file.path(outputFolder ,sp[i], paste0(sp[i],"_st_bbox.gpkg"))
  st_write(sf_bbox_analysis,v_path_bbox_analysis[i],append=F)
  
  print("================== Step 2.2 - Bounding box created =================")
  
  #Create raster
  r_frame <- rast(terra::ext(sf_ext_srs),resolution=spat_res)
  crs(r_frame) <- srs_cube
  values(r_frame) <- 1
  r_aoh <- terra::mask(r_frame,vect(as(sf_area_lim_srs,"Spatial")))
  
  # elevation filters-----------------------------------------------------------
  if(elevation_filter==1){
    # Load elevation preferences
    df_IUCN_sheet <- rredlist::rl_search(sp[i], key = token)$result
    
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
      r_aoh <<- terra::wrap(r_aoh)
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
      r_STRM_range <- cube_STRM_range  |> st_as_stars() |> terra::rast()
      
      # resample to raster of area of habitat
      r_STRM_range_res <- terra::resample(r_STRM_range, r_aoh)
      r_aoh <<- terra::wrap(terra::mask(terra::crop(r_aoh,r_STRM_range_res),r_STRM_range_res)) #Crop to range extent
      
      print("============= Step 2.2.1 - Filter by elevation limits ==============")
    }
    )
  }
  
  r_aoh <- unwrap(r_aoh)
  v_path_to_area_of_habitat[i] <- file.path(outputFolder, sp[i] , paste0(sp[i],"_r_aoh.tif"))
  writeRaster(r_aoh, v_path_to_area_of_habitat[i], overwrite=T, gdal=c("COMPRESS=DEFLATE"), filetype="COG")
  
  print("================== Step 2.3 - Area of habitat created =================")
  
  # get area for the area of habitat delimited by the study area or country
  r_aoh_area <- terra::cellSize(r_aoh,unit="ha")#create raster of areas by pixel
  area_aoh  <- global(r_aoh_area,sum)$sum 
  
  #create dataframe with area values--------------------------------------------
  df_aoh_areas_sp <- tibble(sci_name=sp[i], area_range_map = area_range_map, 
                         area_study_a=area_study_a, area_bbox_analysis=area_bbox_analysis,
                         buff_size=buff_size, area_aoh=area_aoh)
  write_tsv(df_aoh_areas_sp,file.path(outputFolder,sp[i],paste0(sp[i],"_df_aoh_areas.tsv")))
  
  df_aoh_areas <- bind_rows(df_aoh_areas,df_aoh_areas_sp)
  print("================== Step 2.4 - Table of areas =================")
}

path_aoh_areas <- file.path(outputFolder,"df_aoh_areas.tsv")
write_tsv(df_aoh_areas,file= path_aoh_areas)

# Outputing result to JSON -----------------------------------------------------
output <- list("r_area_of_habitat" = v_path_to_area_of_habitat ,
               "sf_bbox" = v_path_bbox_analysis,
               "df_aoh_areas"= path_aoh_areas)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder, "output.json"))