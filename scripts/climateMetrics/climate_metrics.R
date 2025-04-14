library("rjson")
library("terra")

input <- biab_inputs()
# Load climate metric functions
source("/scripts/climateMetrics/climateMetricsFunc.R")

# Load climate
climate_current <- rast(input$climate_current)
climate_future <- rast(input$climate_future)

# Load metric of interest
metric <- input$metric

print(paste("Calculating", metric, "metric..."))

tif <- climate_metrics(climate_current,
                          climate_future,
                          metric,
                          t_match = input$t_match,
                          moving_window = input$moving_window)

layer_paths <- c()
for(i in 1:length(names(tif))){
layer_paths[i] <- paste0(outputFolder, "/", names(tif[[i]]), ".tif")
 terra::writeRaster(x = tif[[i]],
                      layer_paths[i],
                      filetype='COG',
                     options=c("COMPRESS=DEFLATE"),
                     overwrite = TRUE)
}

biab_output("output_tif", layer_paths)

