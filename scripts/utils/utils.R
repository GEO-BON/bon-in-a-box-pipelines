#' @param predictors, a raster, either from raster or terra format
#' @param mask, a vector file, either from raster or terra format
#' @return the predictors raster cropped and masked by mask, in terra format
#' @import terra

fast_crop <- function(predictors,
                       mask) {
  
  # convert into terra raster for increased speed
  if (!inherits(predictors, "SpatRaster")) {
    predictors <- terra::rast(predictors)
  }
  
  # convert into a SpatVector
 if (!inherits(mask, "SpatVectors")) {
    mask <- terra::vect(mask)
  }
predictors <- terra::crop(predictors, mask)
  predictors <- terra::mask(predictors, mask, touches = FALSE)

  # convert to raster format for later processing
     return(predictors)
}


#' @name create_projection
#' @param lon string, name of the longitude column
#' @param lat string, name of the latitude column
#' @param proj_from character, initial projection of the xy coordinates
#' @param proj_to character, target projection
#' @param new_lon character, name of the new longitude column
#' @param new_lat character, name of the new latitude column
#' @return a dataframe with two columns in the proj_to projection
#' @import dplyr
#' 
create_projection <- function(obs, lon, lat, proj_from, 
                              proj_to, new_lon = NULL, new_lat = NULL) {
  
  if(is.null(new_lon)) {
    new_lon <- lon
  }
  
  if(is.null(new_lat)) {
    new_lat <- lat
  }
  
  new.coords <- project_coords(obs, lon, lat, proj_from, proj_to)
  new.coords.df <- data.frame(new.coords) %>% 
    setNames(c(new_lon, new_lat))
  
  suppressWarnings(obs <- obs %>%
                     dplyr::select(-one_of(c(new_lon, new_lat))) %>% dplyr::bind_cols(new.coords.df))
  
  return(obs)
}


#' @name project_coords
#' @param xy data frame, containing the coordinates to reproject
#' @param lon string, name of the longitude column
#' @param lat string, name of the latitude column
#' @param proj_from character, initial projection of the xy coordinates
#' @param proj_to character, target projection
#' @import sp dplyr
#' @return spatial points in the proj_to projection

project_coords <- function(xy, lon = "lon", lat = "lat", proj_from, proj_to = NULL) {
  xy <- dplyr::select(xy, dplyr::all_of(c(lon, lat)))
  sp::coordinates(xy) <-  c(lon, lat)
  sp::proj4string(xy) <- sp::CRS(proj_from)
  
  if (!is.null(proj_to)) {
    xy <- sp::spTransform(xy, sp::CRS(proj_to)) 
    
  }
  xy
}


#' @name points_to_bbox
#' @param xy data frame, containing the coordinates to reproject
#' @param buffer integer, buffer to add around the observations
#' @param proj_from character, initial projection of the xy coordinates
#' @param proj_to character, target projection 
#' @return a box extent
points_to_bbox <- function(xy, buffer = 0, proj_from = NULL, proj_to = NULL) {
  if (!inherits(xy, "SpatialPoints")) {
    sp::coordinates(xy) <- colnames(xy)
    proj4string(xy) <- sp::CRS(proj_from)
  }
  bbox <-  sf::st_buffer(sf::st_as_sfc(sf::st_bbox(xy)), dist =  buffer)
  
  if (!is.null(proj_to) ) {
    bbox <- bbox  %>%
      sf::st_transform(crs = sp::CRS(proj_to))
  }
  
  bbox %>% sf::st_bbox()
}



bbox_to_wkt <- function(xmin = NA, ymin = NA, xmax = NA, ymax = NA, bbox = NULL) {
  if (is.null(bbox)) bbox <- c(xmin, ymin, xmax, ymax)
  stopifnot(is.numeric(as.numeric(bbox)))
  bbox_template <- 'POLYGON((%s %s,%s %s,%s %s,%s %s,%s %s))'
  sprintf(bbox_template, 
          bbox[1], bbox[2],
          bbox[3], bbox[2],
          bbox[3], bbox[4],
          bbox[1], bbox[4],
          bbox[1], bbox[2]
  )
}

shp_to_bbox <- function(shp, proj_from = NULL, proj_to = NULL) {
  if(is.na(sf::st_crs(shp)) && is.null(proj_from)) {
    stop("proj.fom is null and shapefile has no crs.")
  }
  
  if(is.na(sf::st_crs(shp))) {
    crs(shp) <- proj_from
    shp <- shp %>% sf::st_set_crs(proj_from)
  }
  
  if (!is.null(proj_to) ) {
    shp <- shp %>%
      sf::st_transform(crs = sp::CRS(proj_to))
  }
  
  
  bbox <- sf::st_bbox(shp, crs = proj)

  bbox
}





#' @name create_density_plots
#' @param xy data frame, containing the coordinates to reproject
#' @param lon string, name of the longitude column
#' @param lat string, name of the latitude column
#' @param proj_from character, initial projection of the xy coordinates
#' @param proj_to character, target projection
#' @import ggplot2
#' @return spatial points in the proj_to projection
#' @export
create_density_plots <- function(df, factors = NULL, export = T, path = "./density_plot.pdf") {

  df <- df %>% dplyr::mutate_at(.vars = factors, factor)

  i <- 1
  a <- list()
  for (var in names(df)[-which(names(df) %in% c("pa", "lon", "lat", factors))]) {
    
    a[[i]] <- plot_density_cont(df, var)
    i <- i + 1

  }
  j <- 1
  for (f in factors) {
    
    a[[length(a)+j]] <- plot_density_cat(df, f)
    
  }

  p <- do.call(ggpubr::ggarrange, c(a[1:length(a)],  ncol = 3, nrow = 4))

  if (export){
  ggsave(path)
  }

  return(p)
}


plot_density_cont <- function(df, var) {
  vars <- c("pa", var)
  df <- df %>% dplyr::select(dplyr::all_of(vars))
  df <- df[complete.cases(df), ]       
  
  mu <- df %>%
    dplyr::group_by(pa) %>%
    dplyr::summarise_at(all_of(var), list(name = mean))
  
  
  p <- ggplot2::ggplot(df, aes(x = .data[[var]], fill = pa)) +
    ggplot2::geom_density(alpha = 0.4)
  # Add mean lines
  p <- p + ggplot2::geom_vline(data = mu, aes(xintercept = name, color = pa),
                   linetype = "dashed")
  
  return(p)
  
}

