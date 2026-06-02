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
if not id or not secret:
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

# make sure to pass coordinate in meter and not in degree
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

# Step 1: Run the UDP job
print("Starting UDP job to retrieve LAI cube...", flush=True)
udp_job = cube.create_job(
    title=f"LAI UDP {start_year}-{end_year}",
    auto_add_save_result=True,
)
try:
    udp_job.start_and_wait()
except Exception as e:
    biab_error_stop(f"UDP job failed: {e}")

print(f"UDP job finished: {udp_job.job_id}", flush=True)

# Get the canonical STAC link from the job results metadata
job_results = udp_job.get_results()
job_metadata = job_results.get_metadata()
print(f"Job results metadata: {job_metadata}", flush=True)

canonical_links = [
    link["href"]
    for link in job_metadata.get("links", [])
    if link.get("rel") == "canonical" and "href" in link
]

if not canonical_links:
    biab_error_stop("No canonical STAC link found in job results")

stac_url = canonical_links[0]
print(f"Using STAC URL: {stac_url}", flush=True)

# Step 2: Build a new process graph that loads from the STAC URL
print("Building second job to load STAC and aggregate...", flush=True)
lai_cube = connection.load_stac(stac_url)

# add step to resample spatial resolution if needed
if spatial_resolution is None:
    datacube_resampled = lai_cube
else:
    datacube_resampled = lai_cube.resample_spatial(resolution=spatial_resolution, projection=crs, method="bilinear")

# Step 1: calculate max LAI per cell per year
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
    reducer="max",
)
print(yearly_max)

# Step 2: Min of yearly maxima per cell
lai = yearly_max.reduce_dimension(dimension="t", reducer="min")

# Submit aggregation as separate job
lai.save_result("GTiff")
print("Starting aggregation job", flush=True)
job2 = lai.create_job(title=f"LAI aggregation {start_year}-{end_year}")
try:
    job2.start_and_wait()
except Exception as e:
    biab_error_stop(f"openEO job failed: {e}")

rasters = job2.get_results().download_files(output_folder)
print("Job finished:", rasters, flush=True)

raster_outs = [str(r) for r in rasters if not str(r).endswith(".json")]
biab_output("rasters", raster_outs)
