import requests
import pandas as pd
import geopandas as gpd
import os
from copy import deepcopy

inputs = biab_inputs()

token = os.environ['WDPA_API_KEY']
country_iso = inputs['country_iso']
error=[]
if country_iso == '' or country_iso is None or len(country_iso) == 0:
    error.append('Please specify a valid country ISO code')

request_url = "https://api.protectedplanet.net/v3/"

session = requests.Session()

print('Starting download of country bounding box data for %s' % country_iso)
params={"token": token }
results = requests.get("%s/countries/%s" % (request_url, country_iso), params=params).json()
if 'error' in results:
    error.append('ISO Code not found: %s' % results['error'])
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
    results = requests.get("%s/protected_areas/search" % request_url, params=params).json()
    if 'protected_areas' in results and len(results['protected_areas']) > 0:
        pas = results['protected_areas']
        if len(pas) > 0:
            for i in range(len(pas)):
                props = deepcopy(pas[i])
                del(props['geojson'])
                pas[i]['geojson']['properties'] = props
                df = gpd.GeoDataFrame.from_features([pas[i]['geojson']], crs='EPSG:4326')
                all_results = pd.concat([all_results, df])
    else:
        valid_results = False
    total = page*per_page
    print('Protected areas downloaded: %s' % total, flush=True)
    page += 1

out={}
print(all_results)
if (len(error)==0):
    outfile = ("%s/wdpa.gpkg") % (output_folder)
    all_results.to_file(outfile, driver='GPKG', layer='protected_areas')
else:
    out['error']="; ".join(error)

if 'error' in out and out['error']:
	print(out['error'])
	biab_output("error",out['error'] )
else:
    biab_output("protected_area_polygon",outfile)