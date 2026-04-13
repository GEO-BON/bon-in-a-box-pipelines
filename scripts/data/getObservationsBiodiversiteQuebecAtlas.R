library(dplyr)
library(duckdb)
library(rjson)

# Connect to parquet
atlas_con <- dbConnect(duckdb(), read_only = TRUE)
options(timeout = 1000)
dbExecute(atlas_con, "SET temp_directory='/tmp/dbtmp';SET extension_directory='/tmp/dbtmp';")
dbExecute(atlas_con, "INSTALL httpfs;LOAD httpfs;")

base_url <- "https://object-arbutus.cloud.computecanada.ca/bq-io/atlas/parquet/"
atlas_dates <- read.csv(paste0(base_url, "atlas_export_dates.csv"), header = FALSE, col.names = c("dates"))
dbdate <- tail(atlas_dates$dates, n = 1)
file_name <- paste0(base_url, "atlas_public_", dbdate, ".parquet")
dbExecute(atlas_con, paste0("CREATE VIEW atlas AS SELECT * FROM read_parquet('", file_name, "');"))
biab_output("database_date", dbdate)

# Load inputs
input <- biab_inputs()
print("Inputs: ")
print(input)

if (!is.null(input$taxa)) {
  taxa <- input$taxa
} else {
  biab_error_stop("Please specify taxa")
}
# Handle bboxCRS input: reproject to WGS84 float[] if needed
if (!is.null(input$bbox_crs) && !is.null(input$bbox_crs$bbox) && !is.null(input$bbox_crs$CRS)) {
  raw_bbox <- input$bbox_crs$bbox
  proj_string <- paste0(input$bbox_crs$CRS$authority, ":", input$bbox_crs$CRS$code)
  coords1 <- proj4::ptransform(
    cbind(raw_bbox[1], raw_bbox[2]),
    src.proj = proj_string, dst.proj = "+proj=longlat +datum=WGS84"
  )
  coords2 <- proj4::ptransform(
    cbind(raw_bbox[3], raw_bbox[4]),
    src.proj = proj_string, dst.proj = "+proj=longlat +datum=WGS84"
  )
  bbox <- c(
    min(coords1[1], coords2[1]),
    min(coords1[2], coords2[2]),
    max(coords1[1], coords2[1]),
    max(coords1[2], coords2[2])
  )
} else {
  bbox <- FALSE
}
if (!is.null(input$min_year)) {
  min_year <- input$min_year
} else {
  min_year <- FALSE
}
if (!is.null(input$max_year)) {
  max_year <- input$max_year
} else {
  max_year <- FALSE
}

# Build query
selq <- "SELECT *"
whereq <- paste0(" WHERE valid_scientific_name IN(", paste0("'", paste(taxa, collapse = "','"), "'"), ")")
filt <-
  if (length(bbox) > 1) {
    minx <- bbox[1]
    maxx <- bbox[3]
    miny <- bbox[2]
    maxy <- bbox[4]
    selq <- paste0(selq, ", cast(longitude AS DOUBLE) as lng, cast(latitude AS DOUBLE) as lat ")
    whereq <- paste0(whereq, " AND lng >=", minx, " AND lat >= ", miny, " AND lng <= ", maxx, " AND lat <=", maxy)
  }
if (min_year | max_year) {
  selq <- paste0(selq, ", cast(year_obs AS INTEGER) AS yr")
}
if (min_year) {
  whereq <- paste0(whereq, " AND yr >=", min_year)
}
if (max_year) {
  whereq <- paste0(whereq, " AND yr <=", max_year)
}
q <- paste0(selq, " FROM atlas ", whereq)
print(q)
data <- dbGetQuery(atlas_con, q)
data <- data[, !(names(data) %in% c("lat", "lng", "yr", "geom", "geom_bbox"))]
print(data)
biab_output("total_records", nrow(data))

outF <- file.path(outputFolder)
outFile <- paste0(outF, "/Observations.tsv")

# Rename columns to match expected names in downstream scripts
names(data)[names(data) == "longitude"] <- "lon"
names(data)[names(data) == "latitude"] <- "lat"

# Flatten any list-type columns to character to avoid write.csv errors
data <- as.data.frame(lapply(data, function(x) {
  if (is.list(x)) {
    x <- sapply(x, function(v) if (is.null(v)) NA_character_ else as.character(v))
  }
  if (is.character(x) || is.factor(x)) {
    x <- as.character(x)
    x <- gsub("[\r\n\t]", " ", x) 
  }
  return(x)
}), stringsAsFactors = FALSE)

write.table(data, outFile, sep = "\t", row.names = FALSE, quote = FALSE)
biab_output("observations_file", outFile)