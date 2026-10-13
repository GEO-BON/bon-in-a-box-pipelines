input <- biab_inputs()

start <- input$start_year
end <- input$end_year

if (start < 1992) {
  biab_error_stop("Start year must be 1992 or later")
}
if (start > 2019) {
  biab_error_stop("Start year must be 2019 or earlier")
}
if (end > 2020) {
  biab_error_stop("End year must be 2020 or earlier")
}
if (end < 1993) {
  biab_error_stop("End year must be 1993 or later")
}
if (start >= end) {
  biab_error_stop("Start year must be before end year")
}

collection_start <- paste("esacci-lc|esacci-lc-", start, sep = "")
collection_end <- paste("esacci-lc|esacci-lc-", end, sep = "")
collections <- array(c(collection_start, collection_end))

biab_output("collections", collections)
