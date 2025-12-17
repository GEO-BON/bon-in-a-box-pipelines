import ee
import os
import geemap.geemap as geemap
import geopandas as gpd

inputs = biab_inputs()

# Set environment variables (or make sure they're set in your OS)
SERVICE_ACCOUNT = os.environ.get("GEE_SERVICE_ACCOUNT")
KEY_FILE_NAME = os.environ.get("GEE_KEY")  # path to JSON key
KEY_FILE = os.path.join("/userdata/", KEY_FILE_NAME)
print(KEY_FILE)
# Initialize with service account
credentials = ee.ServiceAccountCredentials(SERVICE_ACCOUNT, KEY_FILE)

ee.Initialize(credentials)

gee_layer_name = inputs['gee_layer_name']  # replace or make this dynamic
hab = ee.Image(gee_layer_name)


eez_polygon = gpd.read_file(inputs['polygon'])


hab_clipped = hab.clip(eez_polygon)
print(hab_clipped)

band = inputs['bands']

if band is not None:
    hab_clipped = hab_clipped.select(band)


scale = hab_clipped.projection().nominalScale().getInfo()
print("Pixel resolution (m):", scale)

reef_mask = hab_clipped.eq(1)

resolution = inputs['resolution']

pixel_count = reef_mask.reduceRegion(
    reducer=ee.Reducer.count(),
    geometry=eez_polygon,
    scale=resolution,
    maxPixels=1e13,
    tileScale=16
)


count_value = pixel_count.get('reef_mask').getInfo() 
area_m2 = count_value * scale * scale  # since pixel is 5m × 5m
print("Total reef area (m²):", area_m2)

biab_output("extent", area_m2)