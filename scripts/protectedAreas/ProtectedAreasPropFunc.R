#' @title Creating the protected areas proportion layer, using the world database on protected areas (https://www.protectedplanet.net/en/thematic-areas/wdpa?tab=WDPA)

#' @name protected_areas
#' @param country, character country for which to download data (e.g., "Canada) or ISO-3 codes (e.g., CAN), see https://en.wikipedia.org/wiki/ISO_3166-1_alpha-3
#' @param bbox, a numeric vector of size 4 or 6. Coordinates of the bounding box (if use.obs is FALSE). Details in rstac::stac_search documentation.
#' @param crs, CRS object or a character string describing a projection and datum in the PROJ.4 format (e.g., "EPSG:6623" or "+proj=aea +lat_0=44 +lon_0=-68.5 +lat_1=60 +lat_2=46 +x_0=0 +y_0=0 +datum=NAD83 +units=m +no_defs" ).
#' @param pixel_size, an integer defining the output pixel size in meters. Set at 1000m
#' @param habitat_type,  a character vector of type of habitat c("terrestrial", "marine", "partial"), by default is c("terrestrial")."partial" is a protected area or OECM is that partially within the marine environment and partially within the terrestrial (or freshwater) environments. This value is applicable to polygons only. 
#' @import sf wdpar terra exactextractr dplyr raster
#' @return a raster
#' @export


protected_areas <- function(country = "Canada",
                            bbox = c(-79.76281,  44.99137, -57.10549, 62.58277),
                            crs = "EPSG:6623",
                            pixel_size = 1000,
                            habitat_type = c("terrestrial")
                            ){
  
  # download protected area data for your country (e.g., Canada)
  # (excluding areas represented as point localities)
    print("Loading protected areas data set (wpda) ....")

    raw_pa_data <- wdpar::wdpa_fetch("Canada",
                              wait = TRUE,
                              download_dir = rappdirs::user_data_dir("wdpar") # Since data are downloaded to a temporary directory by default,
                                                                              # we will specify that the data should be downloaded to a persistent directory. This means that R won't have to re-download the same dataset every time we restart our R session,
                                                                              # and R can simply re-load previously downloaded datasets as needed.
                                )

  
  # clean Country data
    print("Cleaning protected areas data set (wpda) ....")
    
    pa_data <- wdpar::wdpa_clean(raw_pa_data,
                          crs = crs,
                          erase_overlaps = F)
  
 
    

    
    
    lat <- c( bbox[4],  bbox[2])
    lon <- c( bbox[1],  bbox[3])
   
    
    # Area of interest within the country (bbox)
    # repair any geometry issues, dissolve the border, reproject to same
    # coordinate system as the protected area data, and repair the geometry again
    print("Loading bbox (i.e., area of interest ....")
    
      poly <-
        data.frame(lon, lat)%>%
        st_as_sf(coords = c("lon", "lat"),
                 crs = "EPSG:4326") %>%
        st_bbox() %>%
        st_as_sfc()%>%
        st_set_precision(pixel_size) %>%
        sf::st_make_valid() %>%
        st_set_precision(pixel_size) %>%
        st_combine() %>%
        st_union() %>%
        st_set_precision(pixel_size) %>%
        sf::st_make_valid() %>%
        st_transform(st_crs(pa_data)) %>%
        sf::st_make_valid()
    
    # Select type of protected areas (e.g., "terrestrial, "marine", "partial") using bbox ('area of interest')
      print(paste0("Selecting type of habitat type = ", habitat_type, " ...."))
      
      pa_data2 <-
        pa_data %>%
        dplyr::filter(MARINE %in% habitat_type) %>%
        sf::st_intersection(poly)
      
    # recalculate the area of each protected area
      print("Recalculating the area of each protected area ....")
      
      pa_data2 <-
        pa_data2 %>%
        dplyr::mutate(AREA_KM2 = as.numeric(st_area(.)) * 1e-6)

    # Create template raster 0.001 (~1000 m)
      print(paste0("Creating a raster template .... Spatial resolution = ", pixel_size, "m", " ...."))
      
      r1 <- terra::rast(ncol=180, nrow=180)
      terra::res(r1) <- c(0.01, 0.01)
      terra::values(r1) <- 1
      
      
      study_area_wgs84<- st_bbox(c(xmin = bbox[1], xmax = bbox[2], ymax = bbox[3], ymin = bbox[4]),
                                 crs = "EPSG:4326")%>%
        st_as_sfc()%>%
        st_as_sf
      

      r_template <- terra::crop(r1, study_area_wgs84)%>%
      terra::project(res=pixel_size, mask=T,align = T, gdal=T, 
                     #"+proj=aea +lat_0=44 +lon_0=-68.5 +lat_1=60 +lat_2=46 +x_0=0 +y_0=0 +datum=NAD83 +units=m +no_defs",
                     crs,
                     method="near")
      
      
    # dissolve polygons into one feature (speed up calculating the fraction of raster cells covered by a polygon)
      print("Dissolving multiple polygons to one polygon feature ....")
      
      pas_dissolved <- sf::st_union(pa_data2$geometry, by_feature = FALSE)
    
   
    # Calculate the fraction of raster cells covered by a polygon
      print("Calculating the the fraction of raster cells covered by a polygon ....") 
      
      proportion_pas <- exactextractr::coverage_fraction(r_template, pas_dissolved, crop = T)
    
      print("Done!")
    
      return(raster::raster(proportion_pas[[1]]))
      
}
 