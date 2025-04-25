
## Load required packages
library("rjson")
library("rstac")
library("tibble")
library("lubridate")
library("sf")
library("dplyr")
library("tidyr")
library("stars")
library("terra")

# Load functions
input <- biab_inputs()
bbox <- input$bbox
# Load bounding box
bbox <- st_bbox(c(xmin = bbox[1], ymin = bbox[2], 
        xmax = bbox[3], ymax = bbox[4]))

n_year <- as.integer(substr(input$t1, 1, 4)) - as.integer(substr(input$t0, 1, 4)) + 1 
temporal_res <- paste0("P", n_year, "Y")

metric <- input$metric

print(paste("Calculating", metric, "metric..."))

# create raster cube from current
current_climate <- rast(input$current_climate)
print("current climate loaded")
print(current_climate)
# create raster cube from future
future_climate <- rast(input$future_climate)

print("future climate loaded")
# Parameters
#cube_current=input$current_climate # (need to input as file)
#cube_future=input$future_climate # (need to input as file)
metric <- input$metric
t_match <- input$t_match
moving_window <- input$moving_window

  
  # Calculate mean current temperature
  #  sum_bands <- paste(names(current_climate), collapse="+")
    
 #   mean_bands <- sprintf("(%s)/%i", sum_bands, length(names(current_climate)))
   
  #  cube_bands <- current_climate[[names(current_climate)]]


        tmean_cube <- app(current_climate, fun = mean, na.rm = TRUE)
        print("printing tmean cube")
print(tmean_cube)
        names(tmean_cube) <- "mean_tmean"
    # Convert to raster
   # tmean_cube_r <- as_stars(tmean_cube)
  #  tmean_cube_r <- rast(tmean_cube_r)
    
    tmean_current_C <- (tmean_cube/10) - 273.15
    print("printing tmean_current_C")
    print(tmean_current_C)
  
  # Calculate mean future temperature

    tmean_future_C <- terra::app(future_climate, fun = function(x) mean(x, na.rm = TRUE) / 10 - 273.15)
    print("printing tmean future c")
    print(tmean_future_C)
    print(str(future_climate))
    print(names(future_climate))
 
  # Time span
year_future <- min(as.numeric(gsub(".*_(\\d{4})-\\d{4}_.*", "\\1", names(future_climate))))
print("printing tmean")
print(names(tmean_cube))
year_current <- min(as.numeric(gsub(".*_(\\d{4})$", "\\1", names(current_climate))))


print("printing year future")
print(year_future)

print("printing year current")
print(year_current)

years_dif <- year_future - year_current
print("printing years diff")
print(years_dif)
    
   srs_cube <- crs(future_climate) 
    
  if(metric == "local"){
  
  # Spatial gradient (meters/?C)
    
    # Neighborhood Slope Algorithm, average maximum technique
      f <- matrix(1, nrow=3, ncol=3)
      x <- tmean_current_C$mean_tmean
      

      w <- matrix(1, nrow = 3, ncol = 3)

# Apply focal function to compute mean absolute difference to neighbors
spatial_tmean_current <- terra::focal(
  x,
  w = w,
  fun = function(x, ...) {
    if (all(is.na(x))) return(NA)
    center <- x[5]
    neighbors <- x[-5]
    mean(abs(neighbors - center), na.rm = TRUE)
  },
  pad = TRUE,
  padValue = NA
)


    # Truncating zero values
      spatial_tmean_current_0 <- spatial_tmean_current
      spatial_tmean_current_0[spatial_tmean_current_0 <= 0.00001] <- 0.00001
      
  # Temporal gradient (?C/year)
    Temporal_tmean <- (tmean_future_C - tmean_current_C)/years_dif
    
  
  # Local climate-change velocity (meters/year)
    local_velocity <- Temporal_tmean/spatial_tmean_current_0
      names(local_velocity) <- "local_climate_velocity"
      
    result <- local_velocity
  }
  
 


################################## FORWARDS VELOCITY ########################################




  
  if(metric == "forward"){
    
    # t_match                                                         # plus/minus threshold to define climate match
    t_match <- 1/(t_match*2)                                          # inverse for rounding, double for plus/minus
  print("done1")


    x <-  terra::crds(tmean_current_C)[,1]                    # vector of grid cell x coordinates

    y <-  terra::crds(tmean_current_C)[,2]                    # vector of grid cell y coordinates

print("done2")
    p <- round(terra::values(tmean_current_C)*t_match)/t_match  
 
    # vector of present climate values for xy coordinates
    
    f <- round(terra::values(tmean_future_C)*t_match)/t_match  
      # vector of future climate values for xy coordinates 
  print("done3")
    d <- vector(length=length(p))                                     # empty vector to write distance to climate match
    
    u     <- unique(p)[order(unique(p))]                              # list of unique climate values in p

    match <- function(u){c(which(u==f))}                              # function finding climate matches of u with f
    
    m     <- sapply(u, match)                                         # list of climate matches for unique values
    print("done4")
    
      for (i in 1:length(p)) {                                        # loop for all grid cells of p
        mi   <- m[[which(u==p[i])]]                                   # recalls list of climate matches for p[i]
        d[i] <- sqrt(min((x[i]-x[mi])^2 + (y[i]-y[mi])^2))            # distance to closest match
        
      }
    print("done5")
    
    # Create matrix with coordinates x and y and distance values
      d[d==Inf] <- 10000000                                           # sets no analogue to 10,000km
      out=cbind(x,y, distance=d) 
    
    # forward_velocity
      # forward_velocity <- raster::rasterFromXYZ(out, res=raster::res(tmean_current_C)[1], crs = srs_cube)%>%
      #   raster::setExtent(tmean_current_C)%>%`/`(1000)%>%
      #   raster::reclassify(c(raster::res(tmean_current_C)[1], raster::res(tmean_current_C)[1], NA), right=NA)%>%`/`(years_dif)%>%
      #   raster::reclassify(c(NA, NA, raster::res(tmean_current_C)[1]), right=raster::res(tmean_current_C)[1])
      # names(forward_velocity) <- "forward_climate_velocity"

    forward_velocity <- rast(out, type="xyz", crs=srs_cube)
    print("printing forward velocity")
    print(forward_velocity)
    # Match resolution and extent
    res(forward_velocity) <- res(tmean_current_C)[1]
    ext(forward_velocity) <- ext(tmean_current_C)

# Divide by 1000 (e.g., convert m to km)
    forward_velocity <- forward_velocity / 1000

# Reclassify: remove values equal to resolution
    rcl1 <- matrix(c(res(tmean_current_C)[1], res(tmean_current_C)[1], NA), ncol=3, byrow=TRUE)
    forward_velocity <- classify(forward_velocity, rcl1, right=NA)

# Divide by time difference
    forward_velocity <- forward_velocity / years_dif

    # Reclassify again: if value is NA, assign it the resolution
  rcl2 <- matrix(c(NA, NA, res(tmean_current_C)[1]), ncol=3, byrow=TRUE)
  forward_velocity <- classify(forward_velocity, rcl2, right=res(tmean_current_C)[1])

# Name the raster layer
names(forward_velocity) <- "forward_climate_velocity"
      
    result <- forward_velocity
  print(result)
  }
  



################################# BACKWARD VELOCITY ################################
   
if(metric == "backward"){
    
   # Let's swap `p` and `f` (i.e., tmean_current_C and tmean_future_C)

    # t_match                                                         # plus/minus threshold to define climate match
    t_match <- 1/(t_match*2)                                          # inverse for rounding, double for plus/minus
    
    x <-  terra::crds(tmean_current_C)[,1]                    # vector of grid cell x coordinates
    y <-  terra::crds(tmean_current_C)[,2]                    # vector of grid cell y coordinates
    
    p <- round(terra::values(tmean_future_C)*t_match)/t_match     # vector of present climate values for xy coordinates
    
    f <- round(terra::values(tmean_current_C)*t_match)/t_match    # vector of future climate values for xy coordinates 
    d <- vector(length=length(p))                                     # empty vector to write distance to climate match
    
    u     <- unique(p)[order(unique(p))]                              # list of unique climate values in p
    
    match <- function(u){c(which(u==f))}                              # function finding climate matches of u with f
    
    m     <- sapply(u, match)                                         # list of climate matches for unique values
    
   
      for (i in 1:length(p)) {                                        # loop for all grid cells of p
        mi   <- m[[which(u==p[i])]]                                   # recalls list of climate matches for p[i]
        d[i] <- sqrt(min((x[i]-x[mi])^2 + (y[i]-y[mi])^2))            # distance to closest match
        
      }
   
      
      # Create matrix with coordinates x and y and distance values
      d[d==Inf] <- 10000000                                           # sets no analogue to 10,000km
      out=cbind(x,y, distance=d) 
      
      # forward_velocity
      # backward_velocity <- raster::rasterFromXYZ(out, res=raster::res(tmean_current_C)[1], crs = srs_cube)%>%
      #   raster::setExtent(tmean_current_C)%>%`/`(1000)%>%
      #   raster::reclassify(c(raster::res(tmean_current_C)[1], raster::res(tmean_current_C)[1], NA), right=NA)%>%`/`(years_dif)%>%
      #   raster::reclassify(c(NA, NA, raster::res(tmean_current_C)[1]), right=raster::res(tmean_current_C)[1])
# Convert XYZ data frame to SpatRaster for backward_velocity
backward_velocity <- rast(out, type="xyz", crs=srs_cube)

# Match resolution and extent
res(backward_velocity) <- res(tmean_current_C)[1]
ext(backward_velocity) <- ext(tmean_current_C)

# Divide by 1000 (e.g., convert m to km)
backward_velocity <- backward_velocity / 1000

# Reclassify: remove values equal to resolution
rcl1 <- matrix(c(res(tmean_current_C)[1], res(tmean_current_C)[1], NA), ncol=3, byrow=TRUE)
backward_velocity <- classify(backward_velocity, rcl1, right=NA)

# Divide by time difference
backward_velocity <- backward_velocity / years_dif

# Reclassify again: if value is NA, assign it the resolution
rcl2 <- matrix(c(NA, NA, res(tmean_current_C)[1]), ncol=3, byrow=TRUE)
backward_velocity <- classify(backward_velocity, rcl2, right=res(tmean_current_C)[1])

# You can rename the layer if needed
names(backward_velocity) <- "backward_climate_velocity"
      
    result <- backwards_velocity
      
    }
    



############################### CLIMATE RARITY ###########################################

    
if(metric == "rarity"){
    print("calculating rarity")

print(moving_window)

rarity_fun <- function(x) {
  if (all(is.na(x))) return(NA)
  focalCell <- ceiling(length(x) / 2)
  ref <- x[focalCell]
  if (is.na(ref)) return(NA)
  
  valid <- !is.na(x)
  similar <- abs(x[valid] - ref) <= t_match
  return(sum(similar) / sum(valid))
}

test_vals <- values(tmean_future_C)  
print(rarity_fun(test_vals))


### test 

# Run focal
tmean_current_rarity <- terra::focal(
  tmean_current_C,
  w = matrix(1, moving_window, moving_window),
  fun = rarity_fun,
 # pad = TRUE,
  fillvalue = NA,
  na.rm = TRUE,
  overwrite = TRUE
)

print("got here")
print(tmean_current_rarity)

#######
names(tmean_current_rarity) <- "climate_current_rarity"


tmean_future_rarity <- terra::focal(
  tmean_future_C,
  w = matrix(1, moving_window, moving_window),
  fun = rarity_fun,
  fillvalue = NA,
  na.rm = TRUE,
  overwrite = TRUE
)

print("done tmean future")                                    

    names(tmean_future_rarity) <- "climate_future_rarity"
    
    climate_rarity <- rast(c(tmean_current_rarity, tmean_future_rarity))
    
    
    result <- climate_rarity
    
    
  }
   


#####
print("printing result")
print(result)
print(class(result))

path <- file.path(outputFolder, "climate_metric.tif")

 terra::writeRaster(x = result,
                      path,
                     overwrite = TRUE)


biab_output("climate_metric_tif", path)




