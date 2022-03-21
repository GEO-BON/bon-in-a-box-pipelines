import sys
sys.path.append('/home/jovyan/getocc/')
import gbif_api
import gbif_pc
import json
import tempfile

# Reading input.json
inputFile = open(sys.argv[1] + '/input.json')
data = json.load(inputFile)

data_source = data['data_source']
taxa = data['taxa'].replace(', ',',').split(',')
bbox = data['bbox'].replace(', ',',').split(',')
years = data['years'].replace(', ',',').split(',')

temp_file = (Path(tempfile.gettempdir()) / next(tempfile._get_candidate_names())).with_suffix(".csv")


if data_source=='gbif_dl':
	gbif_api.gbif_api_dl(splist=taxa, bbox=bbox, years=years, outfile=(str(temp_file)))
elif data_source=='gbif_api':
	gbif_pc.get_taxa_gbif_pc(taxa=taxa, bbox=bbox, outfile=(str(temp_file)))


output = {
  "observations_file": str(temp_file)
}

json_object = json.dumps(output, indent = 2)

with open(sys.argv[1] + '/output.json', "w") as outfile:
  outfile.write(json_object)