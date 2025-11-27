library(rgee)

#ee_clean_pyenv() 
#ee_install()

input <- biab_inputs()

# Connect to google earth engine account
ee_Initialize(
  email = Sys.getenv("GEE_SERVICE_ACCOUNT"),
  key = Sys.getenv("GEE_KEY"),
  service_account = TRUE
)

hab <- ee$Image(input$gee_layer_name) # change to be an unput

# Load EEZ boundary
# eez_polygon <- input$eez

eez_polygon <- ee$Geometry$Rectangle(
  c(-80.60, 20.40, -72.50, 27.50),
  proj = "EPSG:4326",
  geodesic = FALSE
)
# # Clip habitat to Belize
hab_clipped <- hab$clip(eez_polygon)


# Download to your computer
ee_image_to_local(
  image = hab_clipped,
  description = "coral_habitat",
  region = eez_polygon$geometry(),
  scale = 30,
  path = outputFolder, 
  via = "get"
)