import sys;
import json;
import openeo;
import shapely;
import os
import geopandas as gpd
from pyproj import CRS

os.chdir(sys.argv[1])

# Reading inputs
data = biab_inputs()

if (data['bbox_crs']['region'] is not None):
    bbox = data['bbox_crs']['region']['bboxWGS84']
else:
    bbox = data['bbox_crs']['country']['bboxWGS84']
start_year = data['start_year']
end_year = data['end_year']
bands = data['bands']
polygon = data['study_area_polygon']
aggregate_function = data['aggregate_function']
spatial_resolution = data['spatial_resolution']
season = data['season']
crs = data['bbox_crs']['CRS']['authority']+':'+str(data['bbox_crs']['CRS']['code'])
id = os.getenv("CDSE_CLIENT_ID")
secret = os.getenv("CDSE_CLIENT_SECRET")

# input checks
if (int(start_year) < 2017 or int(end_year) > 2024):
    biab_error_stop("Year range must be between 2017 and 2024 inclusively.")

if (id is None or secret == None):
    biab_error_stop("Please specify CDSE credentials in runner.env")

if crs is None or crs=='':
    crs='EPSG:4326'
    print('No CRS specified, using Latitude, Longitude WGS84 (EPSG:4326) as the CRS.')

EPSG = crs.split(':')[1]
coord = CRS.from_epsg(EPSG)

if coord.is_geographic and spatial_resolution > 1:
    biab_error_stop("CRS is in degrees and resolution is in meters.")

if coord.is_projected and spatial_resolution < 1:
    biab_error_stop("CRS is in meters and resolution is in degrees.")

connection = openeo.connect("https://openeo.dataspace.copernicus.eu/")

# put authentication here
connection.authenticate_oidc_client_credentials(
client_id = id,
client_secret = secret,
)

datacube = connection.load_collection(
  "COPERNICUS_VEGETATION_PHENOLOGY_PRODUCTIVITY_10M_" + season,
  spatial_extent={"west": bbox[0], "south": bbox[1], "east": bbox[2], "north": bbox[3]},
  temporal_extent=[start_year, end_year],
  bands=bands
)

gdf = gpd.read_file(polygon)
EPSG = crs.split(':')[1]


gdf = gdf.to_crs(epsg=4326)
tolerance = 0.001
gdf['geometry'] = gdf.geometry.simplify(tolerance, preserve_topology=True)

# Extract the geometry (assuming only one feature)
geometry = gdf.geometry.iloc[0]

if polygon is None:
    datacube_cropped = datacube
else:
    datacube_cropped = datacube.filter_spatial(geometry) # cropping to polygon


if spatial_resolution is None:
    datacube_resampled_cropped = datacube_cropped
else:
    datacube_resampled_cropped = datacube_cropped.resample_spatial(resolution=spatial_resolution, projection=crs, method="bilinear") # resampling to spatial resolution


# output rasters
datacube_resampled_cropped.save_result("GTiff")

# start job to fetch rasters
print("Starting job to fetch raster layers", flush=True)
job1 = datacube_resampled_cropped.create_job()

try:
    job1.start_and_wait()
except Exception as e:
    biab_error_stop("The retrieval of the raster layers failed in openEO, check the log for details.")

rasters = job1.get_results().download_files(output_folder) # these are in file path format

print("Job finished, printing job output", flush=True)
print(rasters)

print(str(rasters[0]), flush=True)
raster_outs = [] # make an empty list
for t in range(len(rasters)- 1):
    raster_outs.append(str(rasters[t])) # get all file paths except json file (last one)

print(raster_outs) # output raster file paths

# Output rasters
biab_output("rasters", raster_outs)

# Start job to calculate summary of phenology values over the polygon

if polygon is None:
    polygon = shapely.geometry.box(*bbox)

res = datacube.aggregate_spatial(
    geometries=geometry,
    reducer=aggregate_function
)

result = res.save_result("CSV")

print("Starting job to calculate phenology values over the polygon of interest", flush=True)

job2 = result.create_job()
job2.start_and_wait()


timeseries = job2.get_results().download_files(output_folder)

print("Job finished, printing job output", flush=True)
print(timeseries)

# output timeseries
timeseries_out = str(timeseries[0])
biab_output("timeseries", timeseries_out)