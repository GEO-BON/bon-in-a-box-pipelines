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

