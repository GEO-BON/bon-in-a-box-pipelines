import sys
import gbif_api
import tempfile
import re
from pyproj import Proj
import datetime

from pathlib import Path

data = biab_inputs()

required_keys = ['GBIF_USER', 'GBIF_PWD', 'GBIF_EMAIL']
if not all(key in os.environ for key in required_keys) or any(os.environ[key] == '' for key in required_keys):
	biab_error_stop("GBIF_USER, GBIF_PWD, and GBIF_EMAIL environment variables must be defined")

taxa = data['taxa']
if taxa=='' or taxa==None or len(taxa)==0:
	biab_error_stop("Please specify taxa")

bbox = data['bbox_crs']['bbox']

if bbox=='' or bbox==None or len(bbox)==0:
	biab_error_stop("Please specify bounding box")

## reading in different possible year formats and converting to int

def parse_year(value, label):
    if value is None or value == "":
        biab_error_stop(f"Please specify a valid {label}")

    if isinstance(value, int):
        year = value
    else:
        value = str(value).strip()

        if re.fullmatch(r"\d{4}", value):
            year = int(value)
        elif re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
            year = int(value[:4])
        else:
            biab_error_stop(
                f"{label} must be a year like 2010 or a date like 2010-01-01"
            )

    current_year = datetime.date.today().year
    if year < 0 or year > current_year:
        biab_error_stop(f"Please specify a valid {label}")

    return year


min_year = parse_year(data["min_year"], "minimum year")
max_year = parse_year(data["max_year"], "maximum year")

if max_year < min_year:
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

print(taxa)
print(sys.argv[1])

if out['total_records'] == 0:
	biab_error_stop("There are no observations for the species selected in the provided study area")


biab_output("observations_file",str(out['outfile']))
biab_output("gbif_doi", str(out['doi']))
biab_output("total_records",str(out['total_records']))
