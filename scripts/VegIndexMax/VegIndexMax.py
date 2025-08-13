import sys;
import json;
import openeo;
import os;
from pyproj import CRS;
import geopandas as gpd;
import shapely;
import pandas as pd;
import matplotlib.pyplot as plt


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

if coord.is_projected and spatial_resolution < 1:
    biab_error_stop("CRS is in meters and resolution is in degrees.")

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

s2 = (
connection.load_collection(
"SENTINEL2_L2A",
temporal_extent=[start_date, end_date],
spatial_extent= {"west": bbox[0], "south": bbox[1], "east": bbox[2], "north": bbox[3], "crs":crs},
bands=["B04","B08"],
max_cloud_cover=20
)
)


scl = (
    connection.load_collection(
    'SENTINEL2_L2A',
    temporal_extent=[start_date, end_date],
    spatial_extent= {"west": bbox[0], "south": bbox[1], "east": bbox[2], "north": bbox[3], "crs":crs},
    bands=["SCL"],
    max_cloud_cover=20
    )
)

mask = scl.process('to_scl_dilation_mask', data=scl)
s2 = s2.mask(mask)


ndvi = s2.ndvi(nir="B08", red="B04", target_band="NDVI")
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

ndvi_resampled = ndvi_cropped.resample_spatial(resolution=spatial_resolution, projection=EPSG, method="average")

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

# Get means for each date of ndvi
if polygon is None:
    polygon = shapely.geometry.box(*bbox)

res = ndvi.aggregate_spatial(
    geometries=polygon,
    reducer=summary_statistic
)

result = res.save_result("CSV")

job2 = result.create_job()
job2.start_and_wait()


timeseries = job2.get_results().download_files(output_folder)

print("Job finished, printing job output", flush=True)
print(timeseries)

# output timeseries
timeseries_out = str(timeseries[0])
biab_output("timeseries", timeseries_out)

# Plot time series
plt.figure(figsize=(8, 5))
plt.plot(timeseries_out["date"], timeseries_out["NDVI"], marker="o", linestyle="-", color="green")

# Formatting
plt.title("NDVI Time Series", fontsize=14)
plt.xlabel("Date", fontsize=12)
plt.ylabel("NDVI", fontsize=12)
plt.grid(True, linestyle="--", alpha=0.5)
plt.ylim(0, 1)  # NDVI values typically range from -1 to 1, but here we set 0–1
plt.tight_layout()


plt.savefig("ndvi_timeseries.png", dpi=300, bbox_inches='tight')
biab_output("timeseries_plot", timeseries_out)