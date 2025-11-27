import ee
import os
import geemap.geemap as geemap

inputs = biab_inputs()
# -----------------------------
# 1. Initialize Earth Engine
# -----------------------------
# Set environment variables (or make sure they're set in your OS)
SERVICE_ACCOUNT = os.environ.get("GEE_SERVICE_ACCOUNT")
KEY_FILE_NAME = os.environ.get("GEE_KEY")  # path to JSON key
KEY_FILE = os.path.join("/userdata/", KEY_FILE_NAME)
print(KEY_FILE)
# Initialize with service account
credentials = ee.ServiceAccountCredentials(SERVICE_ACCOUNT, KEY_FILE)

ee.Initialize(credentials)
print("here")
# -----------------------------
# 2. Load Habitat Image (input)
# -----------------------------
gee_layer_name = inputs['gee_layer_name']  # replace or make this dynamic
hab = ee.Image(gee_layer_name)

# -----------------------------
# 3. Create EEZ bounding box
# -----------------------------
eez_polygon = ee.Geometry.Rectangle([-80.60, 20.40, -72.50, 27.50], proj='EPSG:4326', geodesic=False)
print(hab)
# -----------------------------
# 4. Clip habitat to EEZ
# -----------------------------
hab_clipped = hab.clip(eez_polygon)
print(hab_clipped)

hab_clipped = hab_clipped.select(['reef_mask'])


# Calculate reef extent 
area_image = ee.Image.pixelArea()

reef_area = area_image.updateMask(hab_clipped.eq(1))

scale_value = hab_clipped.projection().nominalScale().getInfo()

stats = reef_area.reduceRegion(
    reducer=ee.Reducer.sum(),
    geometry=eez_polygon,
    scale=scale_value,
    maxPixels=1e13  # Set high to ensure all pixels are included
)

print("STATS")
total_reef_area_sq_m = stats.get('area').getInfo()
print(f"Total Reef Extent (m²): {total_reef_area_sq_m:,.2f}")
# -----------------------------
# 5. Export/download image locally
# -----------------------------

# Use ee.batch.Export.image.toDrive() for large images
outfile = ("%s/gee_layer.tif") % (output_folder)

#Download directly to local file
geemap.ee_export_image(
    hab_clipped,
    filename=outfile,
    scale=1000,
    region=eez_polygon,
    file_per_band=False
)

biab_output("gee_layer", outfile)

