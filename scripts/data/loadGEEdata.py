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
gdf = gpd.read_file(inputs['polygon'])

geom = gdf.geometry.iloc[0]
print(geom)

features = []
for geom in gdf.geometry:
    if geom.geom_type == "Polygon":
        rings = [list(geom.exterior.coords)] + [
            list(r.coords) for r in geom.interiors
        ]
        features.append(ee.Feature(ee.Geometry.Polygon(rings)))

    elif geom.geom_type == "MultiPolygon":
        for poly in geom.geoms:
            rings = [list(poly.exterior.coords)] + [
                list(r.coords) for r in poly.interiors
            ]
            features.append(ee.Feature(ee.Geometry.Polygon(rings)))

ee_fc = ee.FeatureCollection(features)


ee_fc = ee.FeatureCollection(features)

# -----------------------------
# 4. Clip habitat to EEZ
# -----------------------------
hab_clipped = hab.clip(ee_fc)
print(hab_clipped)

bands = inputs['bands']
hab_clipped = hab_clipped.select(bands)


# -----------------------------
# 5. Export/download image locally
# -----------------------------

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

