import asyncio
import os
import sys
from pyproj import Proj
from klab.klab import Klab
from klab.geometry import GeometryBuilder
from klab.observable import Observable
from klab.utils import Export, ExportFormat

inputs = biab_inputs() if 'biab_inputs' in globals() else {}
output_dir = sys.argv[1] if len(sys.argv) > 1 else "/tmp"
os.makedirs(output_dir, exist_ok=True)

def safe_error(message):
    print(f"ERROR: {message}", file=sys.stderr, flush=True)
    if 'biab_error_stop' in globals(): biab_error_stop(message)
    elif 'biab_error' in globals(): biab_error(message)
    else: sys.exit(1)

# credentials
raw_user = os.environ.get("KLAB_USERNAME", "")
raw_pwd = os.environ.get("KLAB_PASSWORD", "")

# strip whitespace, newlines, and quotation marks
klab_username = raw_user.strip(" \t\n\r\"'")
klab_password = raw_pwd.strip(" \t\n\r\"'")

# Error if no credentials
if not klab_username or not klab_password:
    safe_error("KLAB_USERNAME and KLAB_PASSWORD environment variables must be defined in the server's runner.env file.")

study_year     = int(inputs.get("study_year", 2019))
resolution     = inputs.get("resolution", "1 km")

# Bounding box
bbox_crs = inputs.get("bbox_crs")

if bbox_crs and 'bbox' in bbox_crs and 'CRS' in bbox_crs:
    bbox = bbox_crs['bbox']
    proj_string = f"{bbox_crs['CRS'].get('authority', 'EPSG')}:{bbox_crs['CRS'].get('code', '4326')}"
    
    myProj = Proj(proj_string)
    lon1, lat1 = myProj(bbox[0], bbox[1], inverse=True)
    lon2, lat2 = myProj(bbox[2], bbox[3], inverse=True)
    
    min_lon, max_lon = min(lon1, lon2), max(lon1, lon2)
    min_lat, max_lat = min(lat1, lat2), max(lat1, lat2)
    
    wkt_polygon = f"POLYGON(({min_lon} {min_lat}, {max_lon} {min_lat}, {max_lon} {max_lat}, {min_lon} {max_lat}, {min_lon} {min_lat}))"
    study_area_wkt = f"EPSG:4326 {wkt_polygon}"
else:
    # In case left blank
    study_area_wkt = "EPSG:4326 POLYGON((-80.0 43.0, -73.0 43.0, -73.0 47.0, -80.0 47.0, -80.0 43.0))"

KLAB_ENGINE = "https://klab.officialstatistics.org/modeler"
OBSERVABLES = [
    "occurrence of agriculture:Pollinator biology:Insect",
]

async def query_aries_pollination():
    print(f"Connecting to k.LAB engine: {KLAB_ENGINE}", flush=True)
    try:
        klab = Klab.create(
            remoteOrLocalEngineUrl=KLAB_ENGINE,
            username=klab_username,
            password=klab_password,
        )
    except Exception as e:
        safe_error(f"k.LAB authentication failed: {e}")

    print(f"Connected. Building spatial context for WKT: {study_area_wkt}", flush=True)
    try:
        grid = (GeometryBuilder()
                .grid(urn=study_area_wkt, resolution=resolution)
                .years(study_year)
                .build())

        context_obs    = Observable.create("earth:Region")
        
        print("Submitting spatial grid request to k.LAB.", flush=True)
        context_ticket = klab.submit(context_obs, grid)
        
        print("Request accepted by server. Waiting for context to be built.", flush=True)
        context = await context_ticket.get(timeoutSeconds=300)
        
    except Exception as e:
        safe_error(f"Context creation failed or timed out: {e}")

    if context is None:
        safe_error("Context returned None. The server might be overloaded or the bounding box limits were exceeded.")

    print("Context created successfully.", flush=True)

    raster_paths = []
    for observable_str in OBSERVABLES:
        print(f"Querying: {observable_str}", flush=True)
        try:
            obs    = Observable.create(observable_str)
            ticket = context.submit(obs)
            result = await ticket.get(timeoutSeconds=3600)
        except Exception as e:
            safe_error(f"Observable query failed for '{observable_str}': {e}")

        if result is None:
            safe_error(f"No result returned for '{observable_str}'.")

        filename    = observable_str.replace(" ", "_").replace(":", "-") + ".tif"
        raster_path = os.path.join(output_dir, filename)
        result.exportToFile(Export.DATA, ExportFormat.BYTESTREAM, raster_path)
        print(f"Saved: {raster_path}", flush=True)
        raster_paths.append(raster_path)

    return raster_paths

raster_paths = asyncio.run(query_aries_pollination())

if raster_paths and 'biab_output' in globals():
    biab_output("pollinator_raster", raster_paths[0])