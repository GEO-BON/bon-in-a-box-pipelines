import ee
import os
import geemap.geemap as geemap
from shapely import Polygon

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

# -----------------------------
# 2. Load Habitat Image (input)
# -----------------------------
gee_layer_name = inputs['gee_layer_name']  
hab = ee.Image(gee_layer_name)

#Either load bounding box or polygon

polygon = ee.Geometry.Rectangle([-80.60, 20.40, -72.50, 27.50], proj='EPSG:4326', geodesic=False)
# if bounding box
#if input['polygon'] is None:
    #polygon = ee.Geometry.Rectangle(input['bbox'], proj=input['proj'], geodesic=False)
# if polygon
#else:
 #   polygon = polygon = Polygon(input['polygon'])

# -----------------------------
# 4. Clip habitat to EEZ
# -----------------------------
hab_clipped = hab.clip(polygon)
print(hab_clipped)

bands = inputs['bands']
hab_clipped = hab_clipped.select(bands)


# -----------------------------
# 5. Export/download image locally
# -----------------------------

# Use ee.batch.Export.image.toDrive() for large images
outfile = ("%s/gee_layer.tif") % (output_folder)

resolution = inputs['resolution']
#Download directly to local file
geemap.ee_export_image(
    hab_clipped,
    filename=outfile,
    scale=resolution,
    region=polygon,
    file_per_band=False
)

biab_output("gee_layer", outfile)

