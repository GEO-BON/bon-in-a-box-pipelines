from pygbif import occurrences as occ
from pygbif import species as species
from pygbif.occurrences.download import GbifDownload
import pandas as pd
import tempfile
import time
from pathlib import Path
import urllib.request
from zipfile import ZipFile
import os
import csv
from pathlib import Path



def gbif_api_dl(splist=[], bbox=[], years=[1980, 2022],outfile=('out.csv')):
	GBIF_USER=os.environ['GBIF_USER']
	GBIF_PWD=os.environ['GBIF_PWD']
	GBIF_EMAIL=os.environ['GBIF_EMAIL']
	keys = [ species.name_backbone(x)['usageKey'] for x in splist ]
	counts = [ occ.search(taxonKey = x, limit=0)['count'] for x in keys ]
	spcount = dict(zip(splist, counts))
	print(spcount)
	gbif_query = GbifDownload(GBIF_USER, GBIF_EMAIL)
	gbif_query.add_iterative_predicate('TAXON_KEY', keys)
	gbif_query.add_predicate('HAS_COORDINATE', 'TRUE', predicate_type='equals')
	gbif_query.add_predicate('YEAR', years[0], predicate_type='>=')
	gbif_query.add_predicate('YEAR', years[1], predicate_type='<=')
	gbif_query.add_predicate('DECIMAL_LATITUDE', bbox[1], predicate_type='>=')
	gbif_query.add_predicate('DECIMAL_LATITUDE', bbox[3], predicate_type='<=')
	gbif_query.add_predicate('DECIMAL_LONGITUDE', bbox[0], predicate_type='>=')
	gbif_query.add_predicate('DECIMAL_LONGITUDE', bbox[2], predicate_type='<=')
	gbif_query.add_predicate('OCCURRENCE_STATUS', 'PRESENT', predicate_type='equals')
	gbif_query.payload["sendNotification"]=False
	down = gbif_query.post_download(user=GBIF_USER, pwd=GBIF_PWD)
	meta=occ.download_meta(down)
	print(meta)
	while (meta['status']!='SUCCEEDED'):
		meta=occ.download_meta(down)
		time.sleep(10)
	process_gbif_download(meta['downloadLink'], meta['key'],outfile)
	return({'outfile':outfile, 'doi': meta['doi'], 'total_records':meta['totalRecords']})

def process_gbif_download(link, key, outfile):
	temp_input_path = (Path(tempfile.gettempdir()) / next(tempfile._get_candidate_names())).with_suffix(".zip")
	print('Downloading file from GBIF')
	tempzip = urllib.request.urlretrieve(link, temp_input_path)
	print('Extracting occurrence file from ZIP')
	with ZipFile(temp_input_path, 'r') as zipObj:
		zipObj.extract('occurrence.txt', '.')
	df = pd.read_csv('occurrence.txt', sep='\t')
	#df = df[['gbifID','datasetKey','occurrenceID','kingdom','phylum','class','order','family','genus','species','infraspecificEpithet','taxonRank','scientificName','verbatimScientificName','countryCode','locality','stateProvince','occurrenceStatus','individualCount','decimalLatitude','decimalLongitude','coordinateUncertaintyInMeters','coordinatePrecision','elevation','elevationAccuracy','depth','depthAccuracy','eventDate','day','month','year','taxonKey','speciesKey','institutionCode','collectionCode','catalogNumber','recordNumber','basisOfRecord','identifiedBy','dateIdentified','license','rightsHolder','recordedBy','typeStatus','establishmentMeans','lastInterpreted','mediaType','issue']]
	#Convert column names to snake_case
	df.columns = (df.columns
                .str.replace('(?<=[a-z])(?=[A-Z])', '_', regex=True).str.lower()
             )
	df = df[["gbif_id","scientific_name","decimal_longitude","decimal_latitude","year","month","day","basis_of_record","occurrence_status"]]
	df = df.rename(columns={'gbif_id': 'id'})
	print('Saving CSV')
	df.to_csv(outfile, sep ='\t', quoting=csv.QUOTE_NONNUMERIC, doublequote=True, index=False)
