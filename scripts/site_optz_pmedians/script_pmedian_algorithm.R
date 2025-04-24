#pmedian_algorithm for site selection optimization

# it uses a distance matrices from a preselected set of site
# and applies the pmedian teitz and bart problem solution
# so select a subset of site that optimally distributed in geographical and env space 

# call tbart from github mirror if not installed
library(remotes)
if (!'tbart' %in% installed.packages()) {
  remotes::install_github("https://github.com/cran/tbart", force = TRUE)
}else{
  print("spbal package installed locally, not in CONDA")
}

#call needed libraries
library(spbal)
library(terra)
library(sf)
library(tidyterra)
library(ggplot2)
library(tbart)


#read inputs from biab
input <- biab_inputs()  


###########################################################
## calling raw tbart functions to by pass basic input of tbart
###########################################################
print("writing functions for pmedians by pass")

.tb <- function(d,guess,verbose=FALSE) {
  config <- guess
  n <- ncol(d)
  repeat {
    old.config <- config
    config <- .bestswap(d,config,.complement(config,n))
    if (verbose) {
      cat("Configuration: ",config)
      score <- .dtotal(d,config)
      cat("  Score:",score,"\n")
    }
    if (all(old.config==config)) break 
  }
  return(config)
}

.complement <- function(ivec, imax) {
  result <- rep(TRUE,imax)
  result[ivec] <- FALSE
  return(which(result))
}

.bestswap <- function(dm, ins, outs) {
  .Call('tbart_bestswap', PACKAGE = 'tbart', dm, ins, outs)
}

###########################################################
## Calling data (points, rasters, maps, etc)
###########################################################



# 1) locations as dataframe (either sampling site, occurrence of some species, etc.)
# be consistent with the CRS for later steps
print("Loading points")
locs_df <- read.csv(input$locations_csv) ######

# 2) call shapefile of polygon to crop raster layers (if need be)
# be aware of different CRS!!!!
print("Loading map shapefile for plotting")
map_shape <- terra::vect(input$country_polygon)

# 3) call raster layers for env variables
print("Loading and reprojecting map shapefile for plotting")
predictors <- terra:: rast(c(input$rasters))
map_shape<-terra::project(map_shape, predictors) ## call the EPSG string instead? faster??? ask BIAB team

########################## test adding string of epsg instead as biab input


# 4) distance matrices spat, env, and joint

print("Loading joint distance matrix")
mdist <- as.matrix(read.csv(input$mdist) ) ######

env_matrix <- as.matrix(read.csv(input$env_matrix) ) ######


# converting dataframe of points into an sp object
locs_sp <- locs_df # copy the df into a second object which will be the sp object
sp::coordinates(locs_sp) <- ~lon+lat

# produce a randome sample of the locations to start with
n.choices<-length(locs_sp)

set.seed(1234)
p<- 10 ################################################ define in BIAB ???
p <- sample(n.choices,p)


#######################################
#### Allocation for spat and env joint distance matrix
print("Calculating joint allocation with pmedians")
indices <-.tb(mdist,p)

.rviss <- function(dm, ss) {
  .Call('tbart_rviss', PACKAGE = 'tbart', dm, ss)
}

nni <-.rviss(mdist,indices)


alloc_joint <-cbind(nni, locs_df)
names(alloc_joint) <- c("allocation", "lon", "lat")

sp::coordinates(alloc_joint) <- ~lon+lat
agg_occ<-sf::st_as_sf(alloc_joint)

#this does the same as above
#agg_occ<-aggregate(
 # sf::st_as_sf(   
  #  as.data.frame( sp::coordinates(
   #   (locs_sp))) ,coords = c("lon", "lat"), 
    #remove = TRUE )
  #, by = list(nni), head, n=1)

#sf object of joint distance allocation
#sf::st_crs(agg_occ) <- sf::st_crs("EPSG:4326") ### modified to below, it may crash all
print("getting crs of country polygon for sf star diagram 1")
print("step 1")
sf::st_crs(agg_occ) <- sf::st_crs("EPSG:4326") #points are originally in lat lon
print("step 2")
star1<-tbart::star.diagram(alloc_joint, alloc = nni) #sp object will be in CRS of point df (lat lon)
star1_sf <- sf::st_as_sf(star1)
sf::st_crs(star1_sf)<-  sf::st_crs("EPSG:4326")
print("step 3")
# may no need this step for plotting as it may be reprojected on the fly
star1_sf <- sf::st_transform(star1_sf, crs =  sf::st_crs(sf::st_as_sf(map_shape))) # reprojecting to map crs



#############################################
### Allocation for env_matrix only
############################################
print("Calculating Environmental pmedian allocation")


indices <-.tb(env_matrix,p)

.rviss <- function(dm, ss) {
  .Call('tbart_rviss', PACKAGE = 'tbart', dm, ss)
}

nni_env <-.rviss(mdist,indices)




alloc_env <-cbind(nni_env, locs_df)
names(alloc_env) <- c("allocation", "lon", "lat")
sp::coordinates(alloc_env) <- ~lon+lat
agg_env<-sf::st_as_sf(alloc_env)

#this does the same as above
#agg_occ<-aggregate(
# sf::st_as_sf(   
#  as.data.frame( sp::coordinates(
#   (locs_sp))) ,coords = c("lon", "lat"), 
#remove = TRUE )
#, by = list(nni), head, n=1)

#sf object of joint distance allocation
#sf::st_crs(agg_occ) <- sf::st_crs("EPSG:4326") ### modified to below, it may crash all
print("getting crs of country polygon for sf star diagram 2")
print("step 1")
sf::st_crs(agg_env) <- sf::st_crs("EPSG:4326") #points are originally in lat lon
print("step 2")
star2<-tbart::star.diagram(alloc_env, alloc = nni_env) #sp object will be in CRS of point df (lat lon)
star2_sf <- sf::st_as_sf(star2)
sf::st_crs(star2_sf)<-  sf::st_crs("EPSG:4326")
print("step 3")
# may no need this step for plotting as it may be reprojected on the fly
star2_sf <- sf::st_transform(star2_sf, crs =  sf::st_crs(sf::st_as_sf(map_shape))) # reprojecting to map crs


###############################
### Allocation for spatial points (done directly on the points, not matrix)
###############################
print("Calculating Spatial pmedian allocation")

alloc<-tbart::allocate(locs_sp, p=10)

sp_alloc_occ <- aggregate(
  sf::st_as_sf(   
    as.data.frame( sp::coordinates(
      (locs_sp))) ,coords = c("lon", "lat"), 
    remove = TRUE )
  , by = list(alloc), head, n=1)

sf::st_crs(sp_alloc_occ) <- sf::st_crs("EPSG:4326") 

sp_alloc <-cbind(alloc, locs_df) # only for spatail allocation I need this cbind
names(sp_alloc) <- c("allocations", "lon", "lat")
sp::coordinates(sp_alloc) <- ~lon+lat

###############################
### Mapping and plotting clusters of allocations
###############################
print("Mapping and plotting clusters of allocations")

print("Mapping mapping spatial allocation")

spat_pmed_map<-ggplot2::ggplot()+
  tidyterra::geom_spatvector(data =  map_shape )+
  ggplot2::geom_sf(dat =  sp_alloc_occ , ggplot2::aes(color =  as.factor(Group.1)))+
  ggplot2::theme_bw()+
  ggplot2::ggtitle("Spatial p-medians only")+
  ggplot2::theme(legend.position = "none")

print("Mapping joint spatial and env spatial allocation")

spat_env_pmed_map <-ggplot2::ggplot()+
  tidyterra::geom_spatvector(data =  map_shape )+
  ggplot2::geom_sf(dat =  agg_occ , ggplot2::aes(color =  as.factor(allocation)))+
  ggplot2::theme_bw()+
  ggplot2::ggtitle("Spatial and Environmental p-medians")+
  ggplot2::theme(legend.position = "none")

print("Mapping env spatial allocation")

env_pmed_map <-ggplot2::ggplot()+
  tidyterra::geom_spatvector(data =  map_shape )+
  ggplot2::geom_sf(dat =  agg_env , ggplot2::aes(color =  as.factor(allocation)))+
  ggplot2::theme_bw()+
  ggplot2::ggtitle("Environmental p-medians")+
  ggplot2::theme(legend.position = "none")

composite_map <-cowplot::plot_grid(spat_pmed_map,env_pmed_map, spat_env_pmed_map, nrow =1)




###############################
### Mapping and plotting connections of allocations
###############################

#sf object of spatial allocation

print("getting crs of country polygon for sf star diagram 3")

star3<-tbart::star.diagram(sp_alloc, alloc= alloc)
star3_sf <-sf::st_as_sf(star3)

sf::st_crs(star3_sf) <- sf::st_crs("EPSG:4326") 

# may no need this step for plotting as it may be reprojected on the fly
star3_sf <- sf::st_transform(star3_sf, crs =  sf::st_crs(sf::st_as_sf(map_shape))) # reprojecting to map crs

####
print("Plotting STAR MAPS allocation")


print("Plotting STAR spatial allocation")
spat_star_map<- ggplot2::ggplot()+
  tidyterra::geom_spatvector(data =  map_shape )+
  ggplot2::geom_sf(data =sp_alloc_occ,ggplot2::aes(color=as.factor(Group.1)))+
  ggplot2::geom_sf(
    data = star3_sf, col=  "#D55E00" , alpha = 0.2# "#F0E442" # "#009E73"
  )+
  ggplot2::theme_bw()+
  ggplot2::ggtitle("Spatial p-medians only")+
  ggplot2::theme(legend.position = "none")

print("Plotting STAR env allocation")
env_star_map <- ggplot2::ggplot()+
  tidyterra::geom_spatvector(data =  map_shape )+
  ggplot2::geom_sf(data = agg_env ,ggplot2::aes(color=as.factor(allocation)))+
  ggplot2::geom_sf(
    data = star2_sf, col=  "#D55E00" , alpha = 0.2# "#F0E442" # "#009E73"
  )+
  ggplot2::theme_bw()+
  ggplot2::ggtitle("Environmental p-medians")+
  ggplot2::theme(legend.position = "none")

print("Plotting STAR spatial and env allocation")
joint_star_map <- ggplot2::ggplot()+
  tidyterra::geom_spatvector(data =  map_shape )+
  ggplot2::geom_sf(data = agg_occ ,ggplot2::aes(color=as.factor(allocation)))+
  ggplot2::geom_sf(
    data = star1_sf, col=  "#D55E00" , alpha = 0.2# "#F0E442" # "#009E73"
  )+
  ggplot2::theme_bw()+
  ggplot2::ggtitle("Spatial and Environmental p-medians")+
  ggplot2::theme(legend.position = "none")

composite_star_map <-cowplot::plot_grid(spat_star_map,env_star_map, joint_star_map, nrow =1)


#save plot
composite_png_path <- file.path(outputFolder, "composite_pmedians.png") 
ggplot2::ggsave(composite_map, filename= composite_png_path,
                height = 5, width = 15, units = "in" , dpi = 300, bg ="white")
biab_output("composite_map", composite_png_path)


#save plot composite_star_map
composite_star_png_path <- file.path(outputFolder, "composite_star_pmedians.png") 
ggplot2::ggsave(composite_star_map, filename= composite_star_png_path,
                height = 5, width = 15, units = "in" , dpi = 300, bg ="white")
biab_output("composite_star_map", composite_star_png_path)

