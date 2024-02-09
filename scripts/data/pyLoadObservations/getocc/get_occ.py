import sys
sys.path.append('/home/jovyan/scripts/pyLoadObservations/getocc/')
import gbif_api
import gbif_pc
import json
import tempfile
from pyproj import Proj
import datetime

from pathlib import Path

# Reading input.json
inputFile = open(sys.argv[1] + '/input.json')
data = json.load(inputFile)

error=[]
taxa = data['taxa']
if taxa=='' or taxa==None or len(taxa)==0:
	error.append('Please specify taxa')

bbox = data['bbox']
if bbox=='' or bbox==None or len(bbox)==0:
	error.append('Please specify bounding box')

min_year = data['min_year']
if min_year==None or min_year=='' or min_year<0 or min_year>datetime.date.today().year:
	error.append('Please specify a valid minimum year')

max_year = data['max_year']
if max_year==None or max_year=='' or max_year<0 or max_year>datetime.date.today().year:
	error.append('Please specify a valid maximum year')

if max_year<min_year:
	error.append('Please specify proper min and max years')

proj = data['proj']
if proj=='' or ('EPSG' not in proj and 'WKT' not in proj):
	error.append('Please specify proper projection')
else:
	myProj = Proj(proj)
	lon1, lat1 = myProj(bbox[0], bbox[1], inverse=True)
	lon2, lat2 = myProj(bbox[2], bbox[3], inverse=True)
	bbox_wgs84 = [lon1, lat1, lon2, lat2]
	if lon1>lon2 or lat1>lat2 :
		error.append('Please specify a valid bounding box')

data_source = data['data_source']
out={}
if (len(error)==0):
	temp_file = (Path(sys.argv[1]) / next(tempfile._get_candidate_names())).with_suffix(".tsv")
	if data_source=='gbif_api':
		out=gbif_api.gbif_api_dl(splist=taxa, bbox=bbox_wgs84, years=[min_year,max_year], outfile=(str(temp_file)))
	elif data_source=='gbif_pc':
		out=gbif_pc.get_taxa_gbif_pc(taxa=taxa, bbox=bbox_wgs84, years=[min_year,max_year], outfile=(str(temp_file)))
	else:
		print('Please specify proper data source')
else:
	out['error']="; ".join(error)



print(taxa)
print(sys.argv[1])

if 'error' in out and out['error']:
	print(out['error'])
	output = { "error": out['error'] }
else:
	output = {
    "observations_file": str(out['outfile']),
    "gbif_doi": str(out['doi']),
    "total_records": str(out['total_records'])
  }

json_object = json.dumps(output, indent = 2)

with open(sys.argv[1] + '/output.json', "w") as outfile:
  outfile.write(json_object)
