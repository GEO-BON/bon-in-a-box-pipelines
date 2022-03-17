#' Load observations from GBIF or ATLAS databases
#' @name load_observations
#' 
#' @param species, a character, scientific name of the species.
#' @param data_source, an integer, "gbif" or "atlas", source to use
#' @param year_start, an integer, starting year of the period
#' @param year_end, an integer, end year of the period
#' @param extent_wkt, a string in WKT format, used to subset the obs spatially (only used with gbif for now)
#' @param extent_shp, sf polygone, used to subset the obs spatially (only used with gbif for now)
#' @param proj_shp, extent_shp projection system, if not included in extent_shp.
#' @param xmin, a float, xmin coords of extent box (MUST BE IN WGS84), used to subset the obs spatially (only used with gbif for now)
#' @param ymin, a float, ymin coords of extent box (MUST BE IN WGS84), used to subset the obs spatially (only used with gbif for now)#' @param aggregation, a character, aggregation method as string, defining how to deal with pixels containing data from multiple images, can be "min", "max", "mean", "median", or "first"
#' @param xmax, a float, xmax coords of extent box (MUST BE IN WGS84), used to subset the obs spatially (only used with gbif for now)#' @return a raster stack of variables not intercorrelated
#' @param ymax, a float, ymax coords of extent box (MUST BE IN WGS84), used to subset the obs spatially (only used with gbif for now)
#' @param bbox, a vector of float, format: c(xmin, ymin, xmax, ymax) (MUST BE IN WGS84), used to subset the obs spatially (only used with gbif for now)
#' @param limit, an integer, limit param for rgbif::occ_data function
#' @import rgbif dplyr sp sf atlas
#' @return a data.frame

# things to do:
# add spatial filter when loading data from atlas (after import)
# Vincent is fixing a bug to be able to use other filters (month, day)
# add other columns such as species group

load_observations <-
  function(species,
           data_source,
           year_start,
           year_end = NULL,
           extent_wkt = NULL,
           extent_shp = NULL,
           proj_shp = NULL,
           xmin = NA,
           ymin = NA,
           xmax = NA,
           ymax = NA,
           bbox = NULL,
           limit = 1000) {

    # TEMPORAL RANGE
    if (!is.null(year_end) && year_end < year_start) {
      stop("The end year should be higher than the start year.")
    }
    
    year_range <- year_start
    if (!is.null(year_end)) {
      year_range_gbif <-
        paste(year_range, year_end, sep = ",") #string separated by comma
      year_range_atlas <-
        seq(from = year_range, to = year_end) # sequence of integers
      
    }
    
    # SPATIAL RANGE
    if (!is.null(extent_shp)) {
      bbox <-
        shp_to_bbox(shp, proj.from = proj_shp, proj.to = "EPSG:4326")
      if (is.null(bbox)) stop()
      extent_wkt <- bbox_to_wkt(bbox)
    } else if (!is.null(bbox) ||
               (!is.na(xmin) &
                !is.na(ymin) & !is.na(xmax) &  !is.na(ymax))) {
      extent_wkt <-
        bbox_to_wkt(
          xmin = xmin,
          ymin = ymin,
          xmax = xmax,
          ymax = ymax,
          bbox = bbox
        )
    }
    
    if (data_source == "gbif") {
      data <- rgbif::occ_data(
        scientificName = species,
        year = year_range_gbif,
        geometry = extent_wkt,
        hasCoordinate = TRUE,
        limit = limit
      )
      data <- data$data
      if (is.null(data)) {
        warning(sprintf("No observation found for species %s", species))
        data <- data.frame()
      } else {
        data <-
          data %>% dplyr::select(
            key,
            species,
            decimalLongitude,
            decimalLatitude,
            year,
            month,
            day,
            basisOfRecord
          ) %>%
          dplyr::rename(
            id = key,
            scientific_name = species,
            decimal_longitude = decimalLongitude,
            decimal_latitude = decimalLatitude,
            basis_of_record = basisOfRecord
          ) %>%
          dplyr::mutate(basis_of_record = tolower(basis_of_record))%>%
          dplyr::mutate(id = as.character(id))
        
        if (nrow(data) == limit) {
          warning <-
            "Number of observations equals the limit number. Some observations may be lacking."
          
        }
      }
      
    } else if (data_source == "atlas") {
      taxa.id <- ratlas::get_taxa(scientific_name = species)

      
      if (nrow(taxa.id) == 0) {
        warning(sprintf("No observation found for species %s", species))
        data <- data.frame()
      } else {
        taxa.id <- dplyr::pull(taxa.id, id_taxa_obs)
        
        data <-
          try({
            ratlas::get_observations(id_taxa = taxa.id, year = year_range_atlas)
          })
        if (is.data.frame(data) && nrow(data) == 0) {
            warning(sprintf("No observation found for species %s", species))
            data <- data.frame()

          } else {
          coords <- data.frame(data$geom %>% sf::st_coordinates()) %>%
            dplyr::rename(decimal_longitude = X,
                   decimal_latitude = Y)
          
          data <- dplyr::bind_cols(data,
                            coords) %>%
            dplyr::select(
              id,
              taxa_valid_scientific_name,
              decimal_longitude,
              decimal_latitude,
              year_obs,
              month_obs,
              day_obs,
              variable
            ) %>%
            dplyr::rename(
              scientific_name = taxa_valid_scientific_name,
              year = year_obs,
              month = month_obs,
              day = day_obs,
              basis_of_record = variable
            ) %>%
            dplyr::mutate(id = as.character(id))
          
        }
        
        
      }
    }
    return(data)
    
    
  }

