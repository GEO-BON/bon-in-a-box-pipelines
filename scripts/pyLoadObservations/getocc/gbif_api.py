from pygbif import occurrences as occ
from pygbif import species as species
from pygbif.occurrences.download import GbifDownload
import pandas as pd
import tempfile
import time
from pathlib import Path
import urllib.request
from zipfile import ZipFile

def gbif_api_dl(splist=[], bbox=[], years=[1980, 2022],outfile=('out.csv')):
	keys = [ species.name_backbone(x)['usageKey'] for x in splist ]
	counts = [ occ.search(taxonKey = x, limit=0)['count'] for x in keys ]
	spcount = dict(zip(splist, counts))
	print(spcount)
	gbif_query = GbifDownload('glaroc', 'glaroc@gmail.com')
	gbif_query.add_iterative_predicate('TAXON_KEY', keys)
	gbif_query.add_predicate('HAS_COORDINATE', 'TRUE', predicate_type='equals')
	gbif_query.add_predicate('YEAR', years[0], predicate_type='>=')
	gbif_query.add_predicate('YEAR', years[1], predicate_type='<=')
	gbif_query.add_predicate('DECIMAL_LATITUDE', bbox[1], predicate_type='>=')
	gbif_query.add_predicate('DECIMAL_LATITUDE', bbox[3], predicate_type='<=')
	gbif_query.add_predicate('DECIMAL_LONGITUDE', bbox[0], predicate_type='>=')
	gbif_query.add_predicate('DECIMAL_LONGITUDE', bbox[2], predicate_type='<=')
	gbif_query.payload["send_notification"]="false"
	down = gbif_query.post_download()
	meta=occ.download_meta(down)
	while (meta['status']!='SUCCEEDED'):
		meta=occ.download_meta(down)
		time.sleep(10)
	process_gbif_download(meta['downloadLink'],outfile)

def process_gbif_download(link,outfile):
	temp_input_path = (Path(tempfile.gettempdir()) / next(tempfile._get_candidate_names())).with_suffix(".zip")
	print('Downloading file from GBIF')
	tempzip = urllib.request.urlretrieve(link, temp_input_path)
	print('Extracting occurrence file from ZIP')
	with ZipFile(temp_input_path, 'r') as zipObj:
	   zipObj.extract('occurrence.txt', '.')
	df = pd.read_csv('occurrence.txt',sep='\t')
	#df = df[['gbifID','decimalLatitude','decimalLongitude', 'scientificName', 'individualCount', 'organismQuantity', 'organismQuantityType', 'iucnRedListCategory', 'phylum', 'class', 'order', 'family', 'subfamily', 'genus', 'species', 'taxonRank', 'vernacularName','datasetName','year','month','day']]
	df = df[['gbifID','datasetKey','occurrenceID','kingdom','phylum','class','order','family','genus','species','infraspecificEpithet','taxonRank','scientificName','verbatimScientificName','countryCode','locality','stateProvince','occurrenceStatus','individualCount','publisher','decimalLatitude','decimalLongitude','coordinateUncertaintyInMeters','coordinatePrecision','elevation','elevationAccuracy','depth','depthAccuracy','eventDate','day','month','year','taxonKey','speciesKey','institutionCode','collectionCode','catalogNumber','recordNumber','basisOfRecord','identifiedBy','dateIdentified','license','rightsHolder','recordedBy','typeStatus','establishmentMeans','lastInterpreted','mediaType','issue','iucnRedListCategory']]

	print('Saving CSV')
	df.to_csv(outfile)
