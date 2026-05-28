import sys;
import json;
import openeo;
import shapely;
import os
import geopandas as gpd
from pyproj import CRS

# Reading inputs
data = biab_inputs()

if (data['bbox_crs']['region'] is not None):
    bbox = data['bbox_crs']['region']['bboxWGS84']
else:
    bbox = data['bbox_crs']['country']['bboxWGS84']
start_year = data['start_year']
end_year = data['end_year']
polygon = data['study_area_polygon']
spatial_resolution = data['spatial_resolution']
crs = data['bbox_crs']['CRS']['authority']+':'+str(data['bbox_crs']['CRS']['code'])
id = os.getenv("CDSE_CLIENT_ID")
secret = os.getenv("CDSE_CLIENT_SECRET")

start_date = f"{start_year}-01-01"
end_date = f"{end_year}-12-31"

# input checks
if (id is None or secret == None):
    biab_error_stop("Please specify CDSE credentials in runner.env")

if crs is None or crs=='':
    crs='EPSG:4326'
    print('No CRS specified, using Latitude, Longitude WGS84 (EPSG:4326) as the CRS.')

EPSG = crs.split(':')[1]
code = int(crs.split(':')[1])  
coord = CRS.from_epsg(EPSG)

if coord.is_geographic and spatial_resolution > 1:
    biab_error_stop("CRS is in degrees and resolution is in meters.")

if coord.is_projected and spatial_resolution < 1:
    biab_error_stop("CRS is in meters and resolution is in degrees.")

connection = openeo.connect("https://openeo.dataspace.copernicus.eu/")

# authentication 
connection.authenticate_oidc_client_credentials(
client_id = id,
client_secret = secret,
)

#define input parameters
start_date = '2025-06-01'
end_date = '2025-07-01'

# make sure to pass cooordinate in meter and not in degree
aoi = {"west": bbox[0], "south": bbox[1], "east": bbox[2], "north": bbox[3], 'crs': code}
process_graph = "https://raw.githubusercontent.com/ESA-APEx/apex_algorithms/obsgession_lai/algorithm_catalog/obsgession/udp_obsgession_w23_lai/openeo_udp/udp_obsgession_w23_lai.json"

#get cube from udp
cube = connection.datacube_from_process(
    process_id="udp_obsgession_w23_lai",
    namespace=process_graph,
    start_date = start_date,
    end_date = end_date,
    spatial_extent = aoi,
    )


# Step 1: Run UDP as its own job to get a raw raster output
print("Starting UDP job to retrieve LAI cube...", flush=True)
udp_job = cube.create_job(
    title=f"LAI UDP {start_year}-{end_year}",
    auto_add_save_result=False
)

try:
    udp_job.start_and_wait()
except Exception as e:
    biab_error_stop(f"UDP job failed: {e}")

# Re-authenticate before second job
connection.authenticate_oidc_client_credentials(
    client_id=id,
    client_secret=secret,
)

# Load the job result back as a datacube via STAC
lai_cube = connection.load_stac_from_job(
    udp_job
)

# add step to crop to polygon if included

# add step to resample spatial resolution if needed
if spatial_resolution is None:
    datacube_resampled = lai_cube
else:
    datacube_resampled = lai_cube.resample_spatial(resolution=spatial_resolution, projection=crs, method="bilinear") # resampling to spatial resolution


# Step 2: calculate max LAI per cell per year
# build yearly intervals
years = list(range(int(start_year), int(end_year)+1))
print(years)
intervals = [[f"{y}-01-01", f"{y+1}-01-01"] for y in years]
print(intervals)
labels = [f"{y}-07-01" for y in years]  # label each interval with the mid-year date
print(labels)

yearly_max = datacube_resampled.aggregate_temporal(
    intervals=intervals,
    labels=labels,
    reducer="max",       # max LAI within each year
)
print(yearly_max)

# Step 2: Min of yearly maxima per cell
lai = yearly_max.reduce_dimension(dimension="t", reducer="min")

# Submit aggregation as a second job
print("Starting job to compute min of yearly max LAI values", flush=True)
job2 = lai.create_job(
    title=f"Min of yearly max LAI {start_year}-{end_year}",
    out_format="GTiff",
)
try:
    job2.start_and_wait()
except Exception as e:
    biab_error_stop(f"openEO job failed: {e}")

rasters = job2.get_results().download_files(output_folder)
print("Job finished:", rasters, flush=True)

raster_outs = [str(r) for r in rasters if not str(r).endswith(".json")]
biab_output("rasters", raster_outs)

biab_error_stop("*******************")
