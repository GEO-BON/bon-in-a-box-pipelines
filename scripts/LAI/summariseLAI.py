import json;
import openeo;
import os
import geopandas as gpd
from pyproj import CRS
from shapely.geometry import box

# Reading inputs
data = biab_inputs()

if (data['bbox_crs']['bbox'] is not None):
    bbox = data['bbox_crs']['bbox']
else:
    biab_error_stop("No bounding box specified in bbox_crs input.")
    
start_year = data['start_year']
end_year = data['end_year']
polygon = data['study_area_polygon']
spatial_resolution = data['spatial_resolution']
crs = data['bbox_crs']['CRS']['authority']+':'+str(data['bbox_crs']['CRS']['code'])
id = os.getenv("CDSE_CLIENT_ID")
secret = os.getenv("CDSE_CLIENT_SECRET")
if spatial_resolution == "":
    spatial_resolution = None


# Start date
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
    binning_period = "year",
    temp_aggregator = "max",
    epsg = udp_epsg
)

#Run the UDP first, then reload its STAC output as a raster cube.
#print("Starting UDP job to retrieve LAI cube...", flush=True)
#udp_job = cube.create_job(
#    title=f"LAI UDP {start_year}-{end_year}",
#    auto_add_save_result=True,
#)
#try:
#    udp_job.start_and_wait()
#except Exception as e:
#    biab_error_stop(f"UDP job failed: {e}")
#
#print(f"UDP job finished: {udp_job.job_id}", flush=True)

#job_results = udp_job.get_results()
#job_metadata = job_results.get_metadata()

udp_job = cube.save_result(format="GTiff").create_job(
    title=f"LAI UDP GeoTIFF {start_year}-{end_year}"
)
try:
    udp_job.start_and_wait()
except Exception as e:
    biab_error_stop(f"UDP job failed: {e}")

print(f"UDP job finished: {udp_job.job_id}", flush=True)


rasters = udp_job.get_results().download_files(output_folder)
print("Job finished:", rasters, flush=True)


raster_outs = [str(r) for r in rasters if not str(r).endswith(".json")]
biab_output("rasters", raster_outs)

biab_error_stop("just testing first part")

canonical_links = [
    link["href"]
    for link in job_metadata.get("links", [])
    if link.get("rel") == "canonical" and "href" in link
]

if not canonical_links:
    biab_error_stop("No canonical STAC link found in UDP job results.")

stac_url = canonical_links[0]
print(f"Using STAC URL: {stac_url}", flush=True)
lai_cube = connection.load_stac(stac_url)

# crop to study area polygon if provided
if polygon is None or polygon == "":
    lai_cube_cropped = lai_cube
else:
    lai_cube_cropped = lai_cube.filter_spatial(geometry)

# add step to resample spatial resolution if needed
if spatial_resolution is None and input_epsg == udp_epsg:
    datacube_resampled_cropped = lai_cube_cropped
else:
    datacube_resampled_cropped = lai_cube_cropped.resample_spatial(
        resolution=spatial_resolution,
        projection=input_epsg,
        method="bilinear"
    )

# Min of yearly maxima per cell
lai = datacube_resampled_cropped.reduce_dimension(dimension="t", reducer="min")

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
