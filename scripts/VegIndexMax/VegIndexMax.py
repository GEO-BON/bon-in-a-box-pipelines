import sys;
import json;
import openeo;
import os;
from pyproj import CRS;
import geopandas as gpd

data = biab_inputs()

bbox = data['bounding_box']
start_date = data['start_date']
end_date = data['end_date']
polygon = data['study_area_polygon']
spatial_resolution = data['spatial_resolution']
crs = data['crs']
summary_statistic = data['summary_statistic']

if (int(start_date[:4]) < 2017):
    biab_error_stop("The start date must be 2017 or later.")

if crs is None or crs=='':
    crs='EPSG:4326'
    print('No CRS specified, using Latitude, Longitude WGS84 (EPSG:4326) as the CRS.')

EPSG = crs.split(':')[1]
coord = CRS.from_epsg(EPSG)
if coord.is_geographic and spatial_resolution > 1:
    biab_error_stop("CRS is in degrees and resolution is in meters.")

print(crs, flush=True)
connection = openeo.connect("https://openeo.dataspace.copernicus.eu/")

if(os.getenv("CDSE_CLIENT_ID") is None or os.getenv("CDSE_CLIENT_ID")==''):
    error.append('Credential for CDSE not found in runner.env. Please obtain a client ID and client secret keys before running this script.')

# put authentication here
connection.authenticate_oidc_client_credentials(
    client_id=os.getenv("CDSE_CLIENT_ID"),
    client_secret=os.getenv("CDSE_CLIENT_SECRET"),
)

# Load study area polygon
polygon = gpd.read_file(polygon)

# Pull sentinel data and calculate NDVI

# else:
datacube = connection.load_collection(
"SENTINEL2_L2A",
spatial_extent={"west": bbox[0], "south": bbox[1], "east": bbox[2], "north": bbox[3], "crs":crs},
temporal_extent=[start_date, end_date],
bands=["B04", "B08", "SCL"],
max_cloud_cover=20 # select only bands with less than 20% cloud cover
) # load red and infrared bands

# cloud mask
cloud_mask = datacube.process(
    "to_scl_dilation_mask",
    data=datacube,
    kernel1_size=17, kernel2_size=77,
    mask1_values=[2, 4, 5, 6, 7],
    mask2_values=[3, 8, 9, 10, 11],
    erosion_kernel_size=3)

# # claculate NDVI
datacube_masked = datacube.mask(cloud_mask)
# datacube_masked = datacube

ndvi = datacube_masked.ndvi(nir="B08", red="B04", target_band="NDVI")
ndvi = ndvi.filter_bands(bands = ["NDVI"])


ndvi_reduced = ndvi.reduce_dimension(dimension = "t", reducer = summary_statistic)

print(polygon.crs)
if polygon is None:
    ndvi_cropped = ndvi_reduced
else:
    if polygon.crs and polygon.crs.to_epsg() == 4326:
        polygon = json.loads(polygon.to_json())
        
        ndvi_cropped = ndvi_reduced.filter_spatial(polygon) # cropping to polygon
    else:
        print('Reprojecting polygon file to 4326', flush=True)
        repro = json.loads(polygon.to_crs(epsg=4326).to_json())
        crs(repro)
        ndvi_cropped = ndvi_reduced.filter_spatial(repro)

ndvi_resampled = ndvi_cropped.resample_spatial(resolution=spatial_resolution, projection=EPSG)

# output rasters
ndvi_resampled.save_result("GTiff")
# start job to fetch rasters
print("Starting job to fetch raster layers", flush=True)
job1 = ndvi_resampled.create_job()
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

biab_output("rasters", raster_outs)
