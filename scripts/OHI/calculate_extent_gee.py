import ee
import os
import geemap.geemap as geemap
import pandas as pd
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


hab_clipped = hab.clip(ee_fc)
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
    geometry=ee_fc,
    scale=resolution,
    maxPixels=1e13,
    tileScale=16
)


count_value = pixel_count.get('reef_mask').getInfo() 
area_m2 = count_value * scale * scale  
print("Total reef area (m²):", area_m2)

# Make data frame to match the other inputs
coral_extent_df = {
    'habitat': ['coral'],
    'extent': [area_m2]
}

coral_extent_df = pd.DataFrame(coral_extent_df)

csv_path = os.path.join(output_folder, "extent.csv")
coral_extent_df.to_csv(csv_path, index=False)

biab_output("extent", csv_path)