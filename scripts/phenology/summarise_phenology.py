print("Starting script")

import sys;
import json;
import openeo;
import csv;
import os

os.chdir(sys.argv[1])

# Reading input.json
outputFolder = sys.argv[1]
inputFile = open(outputFolder + '/input.json')
data = json.load(inputFile)

bbox = data['bbox']
start_date = data['start_date']
end_date = data['end_date']
bands = data['bands']
polygon = data['study_area_polygon']
aggregate_function = data['aggregate_function']
spatial_resolution = data['spatial_resolution']

connection = openeo.connect("https://openeo.dataspace.copernicus.eu/")

# put authentication here
connection.authenticate_oidc_client_credentials(
client_id=os.getenv("CDSE_CLIENT_ID"),
client_secret=os.getenv("CDSE_CLIENT_SECRET"),
)

datacube = connection.load_collection(
  "COPERNICUS_VEGETATION_PHENOLOGY_PRODUCTIVITY_10M_SEASON1",
  spatial_extent={"west": bbox[0], "south": bbox[1], "east": bbox[2], "north": bbox[3]},
  temporal_extent=[start_date, end_date],
  bands=bands
)

datacube_cropped = datacube.filter_spatial(polygon)

if spatial_resolution is None:
    datacube_resampled_cropped = datacube_cropped
else:
    datacube_resampled_cropped = datacube_cropped.resample_spatial(resolution=spatial_resolution, method="bilinear")

# crop by polygon

# output rasters
datacube_resampled_cropped.save_result("GTiff")
# start job to fetch rasters
print("Starting job to fetch raster layers")
#job1 = datacube_resampled_cropped.create_job()
job1 = connection.job("j-2501311932454b79ac51874683ca8c24")

#job1.start_and_wait()
rasters = job1.get_results().download_files(outputFolder)
#print(rasters)
print(rasters)

print(str(rasters[0]))
raster_outs = []
for t in range(len(rasters)- 1):
    raster_outs.append(str(rasters[t]))

print(raster_outs)
#res = datacube.aggregate_spatial(
 #   geometries=polygon,
#    reducer=aggregate_function
#)


#result = res.save_result("CSV")

#job2=result.create_job()

#print("Starting job to do zonal statistics")
#job2.start_and_wait()


#timeseries = job2.get_results().download_files(outputFolder)

#print(len(timeseries))

#outs = []
#if(len(timeseries)>1):
#    for t in range(len(timeseries)):
#        outs += str(timeseries[t])
#else:
#    outs = str(timeseries[0])
print(rasters)

output = {
 #    "timeseries": str(timeseries[0]),
     "rasters": str(rasters[0]) # also need to figure out how to put this in an array
    }

json_object = json.dumps(output, indent = 2)

with open(outputFolder + '/output.json', "w") as outfile:
    outfile.write(json_object)