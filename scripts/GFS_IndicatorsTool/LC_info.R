library(rjson)
library(terra)
library(sf)


## get bbox from polygons of population
input <- fromJSON(file=file.path(outputFolder, "input.json"))

pop_poly <-st_read(input$population_polygons)

bbox = st_bbox(pop_poly)


## get years of interest
yoi = input$yoi

startY = min(as.numeric(yoi))
endY = max(as.numeric(yoi))

## load land cover data from STAC
load_stac<-function(staccollection='esacci-lc'){
  
  stac_query <- rstac::stac(
    "https://stac.geobon.org/"
  ) |>
    rstac::stac_search(
      collections = staccollection,
      datetime = paste0(startY,"-01-01T00:00:00Z/",endY,"-12-31T23:59:59Z"),
      limit = 50
    ) |>
    rstac::get_request()
  
  make_vsicurl_url <- function(base_url) {
    paste0(
      "/vsicurl",
      "?pc_url_signing=no",
      paste0("&pc_collection=",staccollection),
      "&url=",
      base_url
    )
  }
  
  
  # get download urls
  lcpri_url =   rev(unlist(lapply(stac_query$features, function(x){
    if (x$id%in%paste0('esacci-lc-',yoi)) {
      return(rstac::assets_url(x))
    }
  })))
  
  # make urls readily accessible for stac
  lcpri_url = make_vsicurl_url(lcpri_url)
  
  # open rasters from server
  raster_server = rast(lcpri_url)
  
  # process rasters from server (crop to study area , reasample)
  raster = crop(raster_server, bbox[c(1,3,2,4)]) # crop
  
  return(raster)
}


print("Loading Land Cover from STAC:", )
LC<-load_stac("esacci-lc")


## If classes are set to 0 --> guess top classes from data

  
# get lc classes of first time point at populations polygons
pop_lc= extract(LC[[1]], pop_poly, ID=F)

# sort pop classes (from most frequent to most rare)
pop_lc_sorted = sort(table(pop_lc), decreasing = T)

# find out which classes make up 50% of all pixels at population polygons
pop_lc_sorted_cum = cumsum(pop_lc_sorted) / sum(pop_lc_sorted)

# Convert to a data frame for easier export
pop_lc_sorted_cum_df <- data.frame(
    class = names(pop_lc_sorted_cum),
    prevalence = as.numeric(pop_lc_sorted_cum)
)

# Export to a CSV file
write.csv(pop_lc_sorted_cum_df, file.path(outputFolder, "pop_lc_sorted_cum.csv"), row.names = FALSE)

output <- list("lc_prevalence" = pop_lc_sorted_cum)

jsonData <- toJSON(output, indent=2)
write(jsonData, file.path(outputFolder,"output.json"))