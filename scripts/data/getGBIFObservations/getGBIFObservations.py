import sys
import gbif_api
import tempfile
from pyproj import Proj
import datetime

from pathlib import Path

data = biab_inputs()

taxa = data['taxa']
if taxa=='' or taxa==None or len(taxa)==0:
	biab_error_stop("Please specify taxa")

if data['bbox_crs']=='' or data['bbox_crs']==None or len(data['bbox_crs'])==0:
	biab_error_stop("Please specify bounding box and crs")

bbox = data['bbox_crs']['bbox']

min_year = data['min_year']
if min_year==None or min_year=='' or min_year<0 or min_year>datetime.date.today().year:
	biab_error_stop("Please specify a valid minimum year")

max_year = data['max_year']
if max_year==None or max_year=='' or max_year<0 or max_year>datetime.date.today().year:
	biab_error_stop("Please specify a valid maximum year")

if max_year<min_year:
	biab_error_stop("Please specify proper min and max years")

proj = data['bbox_crs']['CRS']['authority']+':'+str(data['bbox_crs']['CRS']['code'])
if proj=='' or ('EPSG' not in proj and 'WKT' not in proj):
	biab_error_stop("Please specify proper projection")
else:
	myProj = Proj(proj)
	lon1, lat1 = myProj(bbox[0], bbox[1], inverse=True)
	lon2, lat2 = myProj(bbox[2], bbox[3], inverse=True)
	bbox_wgs84 = [lon1, lat1, lon2, lat2]
	if lon1>lon2 or lat1>lat2 :
		biab_error_stop("Please specify a valid bounding box")

out={}

temp_file = (Path(sys.argv[1]) / next(tempfile._get_candidate_names())).with_suffix(".tsv")
out=gbif_api.gbif_api_dl(splist=taxa, bbox=bbox_wgs84, years=[min_year,max_year], outfile=(str(temp_file)))

if int(out['total_records']) == 0:
    biab_error_stop("There are no GBIF occurrences for the chosen species and area.")

print(taxa)
print(sys.argv[1])

biab_output("observations_file",str(out['outfile']))
biab_output("gbif_doi", str(out['doi']))
biab_output("total_records",str(out['total_records']))
