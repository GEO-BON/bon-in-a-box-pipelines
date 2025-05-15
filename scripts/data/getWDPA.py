import requests
import pandas as pd
import geopandas as gpd
import os
from copy import deepcopy
import requests
from requests.adapters import HTTPAdapter

inputs = biab_inputs()

try:
    token = os.environ['WDPA_API_KEY']
except:
    biab_error_stop('API Key not found. Make sure WDPA_API_KEY is properly defined in runner.env')

if token == '' or token is None or len(token) == 0:
    biab_error_stop('API Key is null')

country_iso = inputs['country_iso']
if country_iso == '' or country_iso is None or len(country_iso) == 0:
    biab_error_stop('Please specify a ISO country code')

request_url = "https://api.protectedplanet.net/v3/"

adapter = HTTPAdapter(max_retries=5)
session = requests.Session()
session.mount("http://", adapter)
session.mount("https://", adapter)

print('Starting download of country bounding box data for %s' % country_iso, flush=True)
params={"token": token }
try:
    httpResults = session.get("%s/countries/%s" % (request_url, country_iso), params=params)
    results = httpResults.json()
except:
    print('WDPA API /countries returned error code %s' % httpResults)
    biab_error_stop('Error: Could not retrieve country bounding box from WDPA.')

if 'error' in results:
    biab_error_stop('ISO Code not found: %s' % country_iso)
else:
    country_gpd = gpd.GeoDataFrame.from_features([results['country']['geojson']], crs='EPSG:4326')
    outfile = ("%s/%s_bounding_box.gpkg") % (output_folder, country_iso)
    country_gpd.to_file(outfile, driver='GPKG', layer='country_bounding_box')
    biab_output("country_bounding_box",outfile)


print('Starting download of protected areas data for %s' % country_iso)

all_results = gpd.GeoDataFrame()
valid_results = True
page = 1
per_page = 50
total = 0
while valid_results: 
    params={'country': country_iso, 'page': page, "per_page": per_page, "with_geometry": "true", "token": token }
    try:
        httpResults = session.get("%s/protected_areas/search" % request_url, params=params)
        results = httpResults.json()
    except:
        print('WDPA API /protected_areas returned error code %s' % httpResults)
        biab_error_stop('Error: Could not retrieve protected areas from WDPA.')

    if 'protected_areas' in results and len(results['protected_areas']) > 0:
        pas = results['protected_areas']
        if len(pas) > 0:
            for i in range(len(pas)):
                props = deepcopy(pas[i])
                del(props['geojson'])
                pas[i]['geojson']['properties'] = props
                df = gpd.GeoDataFrame.from_features([pas[i]['geojson']], crs='EPSG:4326').explode()
                all_results = pd.concat([all_results, df])
    else:
        valid_results = False
    total = page*per_page
    print('Protected areas downloaded: %s' % total, flush=True)
    page += 1

out={}
print(all_results.geometry.geom_type.unique())
print(len(all_results))
print(all_results)

outfile = ("%s/wdpa.gpkg") % (output_folder)
all_results.to_file(outfile, driver='GPKG', layer='protected_areas')

biab_output("protected_area_polygon",outfile)