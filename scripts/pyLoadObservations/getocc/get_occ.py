import sys
sys.path.append('/home/jovyan/scripts/pyLoadObservations/getocc/')
import gbif_api
import gbif_pc
import json
import tempfile
from pathlib import Path

# Reading input.json
inputFile = open(sys.argv[1] + '/input.json')
data = json.load(inputFile)

data_source = data['data_source']
taxa = data['taxa'].replace(', ',',').split(',')
bbox = data['bbox'].replace(', ',',').split(',')
years = data['years'].replace(', ',',').split(',')

temp_file = (Path(sys.argv[1]) / next(tempfile._get_candidate_names())).with_suffix(".csv")


print(taxa)
print(sys.argv[1])

if data_source=='gbif_api':
	out=gbif_api.gbif_api_dl(splist=taxa, bbox=bbox, years=years, outfile=(str(temp_file)))
elif data_source=='gbif_pc':
	out=gbif_pc.get_taxa_gbif_pc(taxa=taxa, bbox=bbox, outfile=(str(temp_file)))
else:
	print('Please specify proper data source')


output = {
  "observations_file": str(out)
}

json_object = json.dumps(output, indent = 2)

with open(sys.argv[1] + '/output.json', "w") as outfile:
  outfile.write(json_object)