import sys
sys.path.append('/home/jovyan/scripts/pyLoadObservations/getocc/')
import gbif_api
import gbif_pc
import json
import tempfile
from pyproj import Proj

from pathlib import Path

# Reading input.json
#pa=sys.argv[1]
#pa=pa.rstrip()
#print(pa+'/input.json')
inputFile = open(sys.argv[1] + '/input.json')
data = json.load(inputFile)

data_source = data['data_source']
taxa = data['taxa']
bbox = data['bbox']
min_year = data['min_year']
max_year = data['max_year']
proj = data['proj']
temp_file = (Path(sys.argv[1]) / next(tempfile._get_candidate_names())).with_suffix(".tsv")

myProj = Proj(proj)
lon1, lat1 = myProj(bbox[0], bbox[1], inverse=True)
lon2, lat2 = myProj(bbox[2], bbox[3], inverse=True)

bbox_wgs84 = [lon1, lat1, lon2, lat2]
print(taxa)
print(sys.argv[1])

if data_source=='gbif_api':
	out=gbif_api.gbif_api_dl(splist=taxa, bbox=bbox_wgs84, years=[min_year,max_year], outfile=(str(temp_file)))
elif data_source=='gbif_pc':
	out=gbif_pc.get_taxa_gbif_pc(taxa=taxa, bbox=bbox_wgs84, years=[min_year,max_year], outfile=(str(temp_file)))
else:
	print('Please specify proper data source')


output = {
  "observations_file": str(out['outfile']),
  "gbif_doi": str(out['doi']),
  "total_records": str(out['total_records'])
}

json_object = json.dumps(output, indent = 2)

with open(sys.argv[1] + '/output.json', "w") as outfile:
  outfile.write(json_object)
