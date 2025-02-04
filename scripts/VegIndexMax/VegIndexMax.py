import sys;
import json;
import openeo;
import os

os.chdir(sys.argv[1])

# Reading input.json
outputFolder = sys.argv[1]
inputFile = open(outputFolder + '/input.json')
data = json.load(inputFile)

bbox = data['bounding_box']
start_date = data['start_date']
end_date = data['end_date']
polygon = data['study_area_polygon']
spatial_resolution = data['spatial_resolution']
veg_index = data['vegetation_index']
crs = data['crs']

connection = openeo.connect("https://openeo.dataspace.copernicus.eu/")

# put authentication here
connection.authenticate_oidc_client_credentials(
    client_id=os.getenv("CDSE_CLIENT_ID"),
    client_secret=os.getenv("CDSE_CLIENT_SECRET"),
)
print(veg_index, flush=True)
datacube = connection.load_collection(
  "COPERNICUS_VEGETATION_INDICES",
  spatial_extent={"west": bbox[0], "south": bbox[1], "east": bbox[2], "north": bbox[3], crs:crs},
  temporal_extent=[start_date, end_date],
  bands=veg_index,
)

if polygon is None:
    datacube_cropped = datacube
else:
    datacube_cropped = datacube.filter_spatial(polygon) # cropping to polygon    

if spatial_resolution is None and (crs is None or crs == '4326'):
    datacube_resampled_cropped = datacube_cropped
else:
    datacube_resampled_cropped = datacube_cropped.resample_spatial(resolution=spatial_resolution, projection=crs, method="bilinear") # resampling to spatial resolution

ndvi = datacube_resampled_cropped.reduce_dimension( dimension = "t", reducer = "max")

# output rasters
ndvi.save_result("GTiff")
# start job to fetch rasters
print("Starting job to fetch raster layers", flush=True)
job1 = ndvi.create_job()

job1.start_and_wait()
rasters = job1.get_results().download_files(outputFolder)

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

with open(outputFolder + '/output.json', "w") as outfile:
    outfile.write(json_object)