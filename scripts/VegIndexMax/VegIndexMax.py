import sys;
import json;
import openeo;
import os;
import geopandas as gpd

data = biab_inputs()

bbox = data['bounding_box']
start_date = data['start_date']
end_date = data['end_date']
polygon = data['study_area_polygon']
spatial_resolution = data['spatial_resolution']
veg_index = data['vegetation_index']
crs = data['crs']
ndvi_layer = data['ndvi_layer']

if (int(start_date[:4]) < 2017):
    biab_error_stop("The start date must be 2017 or later.")

if crs is None or crs=='':
    crs='EPSG:4326'
    print('No CRS specified, using Latitude, Longitude WGS84 (EPSG:4326) as the CRS')

print(crs, flush=True)
connection = openeo.connect("https://openeo.dataspace.copernicus.eu/")

if(os.getenv("CDSE_CLIENT_ID") is None or os.getenv("CDSE_CLIENT_ID")==''):
    error.append('Credential for CDSE not found in runner.env. Please obtain a client ID and client secret keys before running this script.')

# put authentication here
connection.authenticate_oidc_client_credentials(
    client_id=os.getenv("CDSE_CLIENT_ID"),
    client_secret=os.getenv("CDSE_CLIENT_SECRET"),
)
print(veg_index, flush=True)

# Load study area polygon
polygon = gpd.read_file(polygon)

if ndvi_layer is "CLMS pre-calcuated (Europe only)": 

    datacube = connection.load_collection(
    "COPERNICUS_VEGETATION_INDICES",
    spatial_extent={"west": bbox[0], "south": bbox[1], "east": bbox[2], "north": bbox[3], "crs":crs},
    temporal_extent=[start_date, end_date],
    bands=["NDVI"],
    )

    ndvi = datacube

# If not in Europe, pull sentinel data and calculate NDVI

else: 
    datacube = connection.load_collection(
    "SENTINEL2_L2A",
    spatial_extent={"west": bbox[0], "south": bbox[1], "east": bbox[2], "north": bbox[3], "crs":crs},
    temporal_extent=[start_date, end_date],
    bands=["B04", "B08"],
    ) # load red and infrared bands


    ndvi = datacube.ndvi(nir="B08", red="B04", target_band="NDVI")
    ndvi = ndvi.filter_bands(bands = ["NDVI"])


ndvi_max = ndvi.reduce_dimension(dimension = "t", reducer = "max")


ndvi_resampled = ndvi_max.resample_spatial(resolution=spatial_resolution, projection=crs)


if polygon is None:
    datacube_cropped = ndvi
else:
    if(crs=='EPSG:4326'):
        polygon = json.loads(polygon.to_json())
        print(polygon)
        datacube_cropped = ndvi.filter_spatial(polygon) # cropping to polygon
    else:
        print('Reprojecting polygon file', flush=True)
        repro = json.loads(polygon.to_crs(crs=None, epsg=crs, inplace=False).to_json())
        datacube_cropped = ndvi.filter_spatial(repro)

datacube_cropped = ndvi


# output rasters
ndvi.save_result("GTiff")
# start job to fetch rasters
print("Starting job to fetch raster layers", flush=True)
job1 = ndvi.create_job()
try:
    job1.start_and_wait()
except Exception as e:
    biab_error_stop("The retrieval of the raster layers failed in OpenEO, check the log for details.")

rasters = job1.get_results().download_files(output_folder)

print("Job finished, printing job output", flush=True)
print(rasters, flush=True)

print(str(rasters[0]), flush=True)
raster_outs = []
for t in range(len(rasters)- 1):
    raster_outs.append(str(rasters[t]))

print(raster_outs)

output = {
    "rasters": raster_outs
}

json_object = json.dumps(output, indent = 2)

with open(output_folder + '/output.json', "w") as outfile:
    outfile.write(json_object)