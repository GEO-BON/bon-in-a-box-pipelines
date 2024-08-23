#-------------------------------------------------------------------------------
# This script measures change on the habitat of the species associated to forest cover
#-------------------------------------------------------------------------------
options(timeout = max(60000000, getOption("timeout")))

packages <- c("rjson","remotes","dplyr","tidyr","purrr","terra","stars","sf","readr","tmap",
              "geodata","gdalcubes","stacatalogue","rredlist","stringr","tmaptools","ggplot2")

if (!"gdalcubes" %in% installed.packages()[,"Package"]) remotes::install_git("https://github.com/appelmar/gdalcubes_R.git")
if (!"stacatalogue" %in% installed.packages()[,"Package"]) remotes::install_git("https://github.com/ReseauBiodiversiteQuebec/stac-catalogue")

new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

lapply(packages,require,character.only=T)

path_script <- Sys.getenv("SCRIPT_LOCATION")

input <- fromJSON(file=file.path(outputFolder, "input.json"))
print("Inputs: ")
print(input)

source(file.path(path_script,"data/filterCubeRangeFunc.R"), echo=TRUE)

output<- tryCatch({
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

# Define species
sp <- str_to_sentence(input$species)

# Bounding box of analysis
v_path_bbox_analysis <- if(is.null(input$sf_bbox)){NA}else{input$sf_bbox}

# Area of habitat
v_path_to_area_of_habitat <- if(is.null(input$r_area_of_habitat)){NA}else{input$r_area_of_habitat}

#forest threshold for GFW (level of forest for the species)
min_forest <- if(is.null(input$min_forest)){NA}else{input$min_forest}
max_forest <- if(is.null(input$max_forest)){NA}else{input$max_forest}

#define time steps
t_0 <- input$t_0
t_n <- input$t_n # should be larger than t_0 at least 2 years needed
time_step <- input$time_step
t_range <- ((t_n - t_0)/time_step)
v_time_steps <- seq(t_0,t_n,time_step)

#-------------------------------------------------------------------------------
v_path_SHS_map <- c()
v_path_SHS <- c()
l_path_habitat_by_tstep <- list()
v_path_img_SHS_timeseries <- c()
v_path_SHS_tidy <- c()

for(i in 1:length(sp)){
  #-------------------------------------------------------------------------------------------------------------------
  #1. Load inputs
  #-------------------------------------------------------------------------------------------------------------------

  sf_bbox_analysis <- st_read(v_path_bbox_analysis[i])
  sf_ext_srs <- sf_bbox_analysis |> st_bbox()
  print(sf_ext_srs)
  print(v_path_to_area_of_habitat[i])

  r_aoh <- rast(v_path_to_area_of_habitat[i])
  print(r_aoh)
  
  if (!dir.exists(file.path(outputFolder,sp[i]))){
    dir.create(file.path(outputFolder,sp[i]))
  }else{
    print("dir exists")
  }

  #-------------------------------------------------------------------------------------------------------------------
  #2. Land Cover Values
  #-------------------------------------------------------------------------------------------------------------------
  #2.1 GFW data-------------------------------------------------------------------
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

  if(is.na(min_forest[i])  & is.na(max_forest[i])){
    print("--- At least one level of tree cover percentage is needed ---")
  }else{
    cube_GFW_TC_threshold <<- funFilterCube_range(cube_GFW_TC,min=min_forest[i],max=max_forest[i],value=FALSE)
  }
  r_GFW_TC_threshold <- cube_to_raster(cube_GFW_TC_threshold , format="terra") # convert to raster format
  r_GFW_TC_threshold <- r_GFW_TC_threshold |>
    terra::classify(rcl=cbind(NA,0)) # turn NA to 0

  r_aoh_rescaled <- terra::resample(r_aoh,r_GFW_TC_threshold,method="mode") #Adjust scale of range map

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
  
  print("========== Forest loss layer downloaded ==========")

  times <- as.numeric(substr(v_time_steps[v_time_steps>2000],start=3,stop=4))

  l_year_loss <- map(times, ~ funFilterCube_range(cube = cube_GFW_loss, max=.x, type_max=1, min=1, type_min=1, value=FALSE))
  # turn cube to raster
  l_r_year_loss <- map(l_year_loss, cube_to_raster, format="terra")
  s_year_loss_w_nas <- rast(l_r_year_loss) 
  # turn NAs into 0 for raster operations
  s_year_loss <- s_year_loss_w_nas |> terra::classify(rcl=cbind(NA,0)) # faster than with ifel

  #if t_0 different of 2000 update reference forest layer "r_GFW_TC_threshold_mask" by subtracting t0 to base forest layer from 2000
  if(t_0!=2000){
    names(s_year_loss) <- paste0("Loss_",v_time_steps)
    print("Asign names to layers")
    # get first year for habitat in t0
    s_year_loss_t0 <- terra::subset(s_year_loss,paste0("Loss_",t_0))
    cat("Create t0 layer with: ", paste0("Loss_",t_0),"\n")
    s_year_loss <- terra::subset(s_year_loss,subset=paste0("Loss_",v_time_steps[v_time_steps>t_0]))
    cat("Create new loss layers without t0: ", paste0("Loss_",v_time_steps[v_time_steps>t_0],collapse=", "),"\n")
    r_GFW_TC_threshold <- terra::classify(r_GFW_TC_threshold - s_year_loss_t0,rcl=cbind(-1,0))
    print("Create new base habitat layer")
  }else{
    names(s_year_loss) <- paste0("Loss_",v_time_steps[v_time_steps>t_0])
  }
  
  # mask t0 to AOH
  r_GFW_TC_threshold_mask <- r_GFW_TC_threshold |>
    terra::mask(r_aoh_rescaled) # mask to range map
  
  # mask to t0
  s_year_loss_mask <- terra::mask(s_year_loss,r_GFW_TC_threshold_mask, maskvalues=1, inverse=TRUE)
  # extract last year
  cat("Extract last year: ",paste0("Loss_",t_n),"\\n")
  s_year_loss_tn <- terra::subset(s_year_loss_mask,paste0("Loss_",t_n))
  
  
  
  #-------------------------- figure ----------------------------------------------
  r_year_loss_mask_plot <- terra::classify(s_year_loss_tn,rcl=cbind(0,NA)) # turn 0 to NA

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
  
  print("========== Forest gain layer downloaded ==========")
  
  r_GFW_gain <- cube_to_raster(cube_GFW_gain , format="terra") # convert to raster format
  r_GFW_gain_mask <- terra::classify(terra::mask(r_GFW_gain ,r_aoh_rescaled),rcl=cbind(0,NA))

  #load world limits
  sf_world_lim <- st_read(file.path(path_script,"SHI/world-administrative-boundaries.gpkg"))

  img_map_habitat_changes <- tm_shape(sf_world_lim,bbox=st_bbox(r_GFW_TC_threshold_mask))+tm_polygons(col="white",fill="#c2bbac")+
    tm_shape(r_aoh)+tm_raster(alpha=0.4,palette = c("#E8E9EB"),legend.show=FALSE)+
    tm_shape(r_GFW_TC_threshold_mask)+tm_raster(style="cat",alpha=0.5,palette = c("#0000FF00","blue"), legend.show = FALSE)+
    tm_shape(r_year_loss_mask_plot)+tm_raster(style="cat",palette = c("red"), legend.show = FALSE)+
    tm_shape(r_GFW_gain_mask)+tm_raster(style="cat",alpha=0.8,palette = c("yellow"), legend.show = FALSE)+
    tm_compass(position=c("right","bottom"))+tm_scale_bar(position=c("left","top"))+
    tm_layout(bg.color="lightblue",legend.bg.color = "white",legend.bg.alpha = 0.5,legend.outside = F)+
    tm_add_legend(labels=c("No change","Loss","Gain"),col=c("blue","red","yellow"),title="Area of Habitat")

  v_path_SHS_map[i] <- file.path(outputFolder,sp[i],paste0(sp[i],"_GFW_change.png"))
  tmap_save(img_map_habitat_changes, v_path_SHS_map[i])
  
  print("========== Map of changes in suitable area generated ==========")

  #create non masked layers for distance metrics
  s_habitat0_nomask <- terra::classify(r_GFW_TC_threshold-s_year_loss,rcl=cbind(-1,0))
  
  s_habitat_nomask <- c(r_GFW_TC_threshold, s_habitat0_nomask)
  # rm(s_habitat0_nomask)
  names(s_habitat_nomask) <- paste0("habitat_",v_time_steps)

  s_habitat <- terra::mask(s_habitat_nomask , r_aoh_rescaled )
  s_habitat <- terra::classify(s_habitat , rcl=cbind(0,NA))
  
  l_path_habitat_by_tstep[[i]] <- file.path(outputFolder, sp[i], paste0(sp[i],"_GFW_",names(s_habitat),".tif"))
  print(l_path_habitat_by_tstep[[i]])
  map2(as.list(s_habitat), unlist(l_path_habitat_by_tstep[[i]]), ~terra::writeRaster(.x,filename=.y,overwrite=T, gdal=c("COMPRESS=DEFLATE"), filetype="COG"))
  print(list.files(file.path(outputFolder,sp[i], pattern = "habitat", full.names = T)))

  print("========== Map of habitat created ==========")
  #-------------------------------------------------------------------------------------------------------------------
  #3. Measure scores
  #-------------------------------------------------------------------------------------------------------------------

  # Area Score--------------------------------------------------------------------
  r_areas <- terra::cellSize(s_habitat[[1]],unit="ha")#create raster of areas by pixel

  s_habitat_area <- s_habitat * r_areas
  habitat_area <- terra::global(s_habitat_area, sum, na.rm=T)

  df_area_score_gfw <- tibble(sci_name=sp[i], Year= v_time_steps, Area=units::set_units(habitat_area$sum,"ha")) |>
    dplyr::mutate(ref_area=first(Area)) |> dplyr::group_by(Year) |> mutate(diff=ref_area-Area, percentage=as.numeric(Area*100/ref_area),score="AS")

  print(df_area_score_gfw)

  write_tsv(df_area_score_gfw,file.path(outputFolder,sp[i],paste0(sp[i],"_df_area_score.tsv")))
  print("========== Habitat Score generated ==========")

  # Connectivity score  ---------------------------------------------------------
  l_habitat_dist <- map(as.list(s_habitat_nomask), ~gridDist(.x, target=0)) # calculate distance to edge
  gc(T)
  map2(as.list(l_habitat_dist), v_time_steps,~writeRaster(.x,file.path(outputFolder,sp[i],paste0(sp[i],"_dist_to_edge_",.y,".tif")),overwrite=T))

  s_habitat_dist <- mask(rast(l_habitat_dist),s_habitat,maskvalues=1,inverse=T)
  df_habitat_dist <- global(s_habitat_dist,mean,na.rm=T)

  df_conn_score_gfw <- tibble(sci_name=sp[i], Year=v_time_steps, value=df_habitat_dist$mean) |> mutate( ref_value=first(value)) |>
    dplyr::group_by(Year) |> mutate(diff=ref_value-value, percentage=(value*100)/ref_value,score="CS")
  df_conn_score_gfw

  write_tsv(df_conn_score_gfw,file.path(outputFolder,sp[i],paste0(sp[i],"_df_conn_scoreGISfrag.tsv")))
  print("========== Connectivity Score generated ==========")


  #------------------------ 3.1.3. SHS -------------------------------------------
  df_SHS_gfw <- data.frame(sci_name=sp[i], AS=as.numeric(df_area_score_gfw$percentage),CS=df_conn_score_gfw$percentage)
  print(df_SHS_gfw)
  df_SHS_gfw <- df_SHS_gfw |> dplyr::mutate(SHS=(AS+CS)/2, info="GFW", Year=v_time_steps)
  print(df_SHS_gfw)
  
  df_SHS_gfw_tidy <- df_SHS_gfw |> pivot_longer(c("AS","CS","SHS"),names_to = "Score", values_to = "Values")
  v_path_SHS_tidy[i] <- file.path(outputFolder,sp[i],paste0(sp[i],"_SHS_table_tidy.tsv"))
  print(df_SHS_gfw_tidy)
  write_tsv(df_SHS_gfw_tidy,file= v_path_SHS_tidy[i])
  
  colnames(df_SHS_gfw) <- c("Species","Area Score","Connectivity Score","Species Habitat Score","Source","Year")
  print(df_SHS_gfw)

  v_path_SHS[i] <- file.path(outputFolder,sp[i],paste0(sp[i],"_SHS_table.tsv"))
  write_tsv(df_SHS_gfw,file= v_path_SHS[i])


  print("========== Species Habitat Score generated ==========")

  img_SHS_timeseries <- ggplot(df_SHS_gfw_tidy , aes(x=Year,y=Values,col=Score))+
    geom_line(linewidth=1)+geom_point()+scale_y_continuous(breaks=seq(0,110,10))+
    theme_bw()+scale_colour_brewer(palette="Dark2")+ coord_cartesian(ylim=c(0,110))+
    ylab("Connectivity Score (CS), Habitat Score (HS), \n Species Habitat Score (SHS)")

  v_path_img_SHS_timeseries[i] <- file.path(outputFolder,sp[i],paste0(sp[i],"_SHS_timeseries.png"))
  ggsave(v_path_img_SHS_timeseries[i],img_SHS_timeseries,dpi = 300,width=8,height = 5)

}

path_habitat_by_tstep <- unlist(l_path_habitat_by_tstep)
print(path_habitat_by_tstep)
print(v_path_SHS_map)
print(v_path_img_SHS_timeseries)

# Outputing result to JSON
output <- list( "img_shs_map" = v_path_SHS_map,
                "r_habitat_by_tstep" = path_habitat_by_tstep ,
                "img_shs_timeseries" = v_path_img_SHS_timeseries,
                "df_shs" = v_path_SHS,
                "df_shs_tidy" = v_path_SHS_tidy)

}, error = function(e) { list(error = conditionMessage(e)) })

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder, "output.json"))
