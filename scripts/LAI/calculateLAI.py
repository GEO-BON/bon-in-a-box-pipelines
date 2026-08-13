import json;
import openeo;
import os
import geopandas as gpd
from pyproj import CRS
from shapely.geometry import box

# Reading inputs
data = biab_inputs()
    
start_year = data['start_year']
end_year = data['end_year']
polygon = data['study_area_polygon']
spatial_resolution = data['spatial_resolution']
crs = data['bbox_crs']['CRS']['authority']+':'+str(data['bbox_crs']['CRS']['code'])
binning_period = data['binning_period']
id = os.getenv("CDSE_CLIENT_ID")
secret = os.getenv("CDSE_CLIENT_SECRET")
if spatial_resolution == "":
    spatial_resolution = None

# input checks

if (binning_period is None or binning_period == ""):
    binning_period = "year"

if (data['bbox_crs']['bbox'] is not None):
    bbox = data['bbox_crs']['bbox']
else:
    biab_error_stop("No bounding box specified in bbox_crs input.")

# Start date
if start_year is None or int(start_year) < 2015:
    start_year = "2015"
    biab_warning("Start year for LAI is set to 2015, as the data is only available from 2015 onwards.")

if "-" in str(start_year):
    start_date = start_year
else:
    start_date = f"{start_year}-01-01"

# End date
if "-" in str(end_year):
    end_date = end_year
else:
    end_date = f"{end_year}-12-31"

input_crs = crs
udp_crs = "EPSG:3035"
udp_epsg = 3035

# input checks
if not id or not secret:
    biab_error_stop("Please specify CDSE credentials in runner.env")

input_epsg = int(input_crs.split(":")[1])
input_coord = CRS.from_epsg(input_epsg)

if input_coord.is_geographic:
    biab_error_stop("CRS is in degrees and must be in meters.")

if spatial_resolution is not None and input_coord.is_projected and spatial_resolution < 1:
    biab_error_stop("CRS is in meters and resolution is in degrees.")

if polygon is None or polygon == "":
    if input_epsg != udp_epsg:
        bbox_geom = gpd.GeoDataFrame(
            geometry=[box(*bbox)],
            crs=input_crs
        ).to_crs(udp_crs)

        west, south, east, north = bbox_geom.total_bounds
        bbox = [west, south, east, north]

geometry = None

if polygon is not None and polygon != "":
    gdf = gpd.read_file(polygon)

    if gdf.empty:
        biab_error_stop("Study area polygon file does not contain any features.")

    # UDP needs polygon/bbox in EPSG:3035
    gdf = gdf.to_crs(udp_crs)

    for col in gdf.select_dtypes(include=["datetime64"]).columns:
        gdf[col] = gdf[col].astype(str)

    geometry = json.loads(gdf.to_json())

    west, south, east, north = gdf.total_bounds
    bbox = [west, south, east, north]

connection = openeo.connect("https://openeo.dataspace.copernicus.eu/")

# authentication 
connection.authenticate_oidc_client_credentials(
    client_id = id,
    client_secret = secret,
)

aoi = {"west": bbox[0], "south": bbox[1], "east": bbox[2], "north": bbox[3], "crs": udp_epsg}
process_graph = "https://raw.githubusercontent.com/ESA-APEx/apex_algorithms/obsgession_lai/algorithm_catalog/obsgession/udp_obsgession_w23_lai/openeo_udp/udp_obsgession_w23_lai.json"

#get cube from udp
cube = connection.datacube_from_process(
    process_id="udp_obsgession_w23_lai",
    namespace=process_graph,
    start_date = start_date,
    end_date = end_date,
    spatial_extent = aoi,
    binning_period = binning_period,
    temp_aggregator = "max",
    epsg = udp_epsg
)

udp_job = cube.save_result(format="GTiff").create_job(
    title=f"LAI UDP GeoTIFF {start_year}-{end_year}"
)

try:
    udp_job.start_and_wait()
except Exception as e:
    # Fetch and print logs BEFORE stopping, so you actually see them
    try:
        for entry in udp_job.logs(level = "error"):
            print(f"[{entry.get('level')}]: {entry.get('message')}", flush=True)
    except Exception as log_err:
        print(f"Could not retrieve logs: {log_err}", flush=True)
    biab_error_stop(f"UDP job failed: {e}")

# If it succeeded, you can still print logs (e.g. warnings/info) here
for entry in udp_job.logs(level = "warning"):
    print(f"[{entry.get('level')}]: {entry.get('message')}", flush=True)

print(f"UDP job finished: {udp_job.job_id}", flush=True)


rasters = udp_job.get_results().download_files(output_folder)
print("Job finished:", rasters, flush=True)

print(str(rasters[0]), flush=True)
raster_outs = [] # make an empty list
for t in range(len(rasters) - 1):
    raster_outs.append(str(rasters[t])) # get all file paths except json file (last one)

print(raster_outs) # output raster file paths

# Output rasters
biab_output("rasters", raster_outs)
