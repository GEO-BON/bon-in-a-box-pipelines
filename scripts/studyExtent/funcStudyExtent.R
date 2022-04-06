#' @name create_study_extent
#' @param xy data frame, containing the coordinates to reproject
#' @param lon string, name of the longitude column
#' @param lat string, name of the latitude column
#' @param proj character, initial projection of the xy coordinates
#' @return spatial points
#' @export
create_study_extent <- function(obs, 
                              lon = "lon",
                              lat = "lat",
                              proj = proj,
                              method = "box",
                              dist_buffer = NULL,
                              shapefile_path = NULL,
                              export = NULL,
                              path = NULL,
                              species = NULL) {
  
  # projecting observations coordinates
  obs_points <- project_coords(obs, lon, lat, proj)
  
  
  if (method == "box") {
    message(sprintf("Calculating study extent based on box around observations
                    (with buffer = %i)
                    ", dist_buffer))
    
    
    # Creating box extent around obs
    study_extent <-  sf::st_as_sfc(sf::st_bbox(obs_points, crs = sp::CRS(proj))) %>%
      sf::st_as_sf()
    
    if (!is.null(dist_buffer)) {
      study_extent <-  sf::st_buffer(study_extent, dist =  dist_buffer)
    }
    
    # Buffering box extent
    
  } else if (method ==  "mcp") {
    study_extent <- mcp(obs_points)
    
    if (!is.null(dist_buffer)) {
      study_extent <-  sf::st_buffer(study_extent, dist =  dist_buffer)
    }
    
  } else if (method == "buffer") {
    message(sprintf("Calculating study extent based on buffer around observations
                    (with buffer = %i)
                    ", dist_buffer))
    
    
    study_extent_multi <- rgeos::gBuffer(spgeom = obs_points,
                                         byid = T, width = dist_buffer)
    
    study_extent <-  study_extent_multi %>% 
      sf::st_as_sfc(crs = sp::CRS(proj)) %>% 
      sf::st_union(by_feature = F)
    
  } else if (method == "user_shapefile") {
    
    study_extent <- sf::st_read(shapefile_path) 
  }
  study_extent <- study_extent %>% sf::st_set_crs(proj)
 
  return(study_extent)
  
}


mcp <- function(obs_points) {
  xy <- as.data.frame(obs_points@coords)
  coords.t <- chull(xy[, 1], xy[, 2])
  xy.bord <- xy[coords.t, ]
  xy.bord <- rbind(xy.bord[nrow(xy.bord), ], xy.bord)
  mcp <- sp::SpatialPolygons(list(sp::Polygons(list(sp::Polygon(as.matrix(xy.bord))), 1))) %>%
    sf::st_as_sf()  
  return(mcp)
}
