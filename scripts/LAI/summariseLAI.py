import sys;
import json;
import openeo;
import shapely;
import os
import geopandas as gpd
from pyproj import CRS



data = biab_inputs()

bbox = data['bbox_crs']['bbox']
start_date = data['start_date']
end_date = data['end_date']
polygon = data['study_area_polygon']
spatial_resolution = data['spatial_resolution']
crs = data['bbox_crs']['CRS']['authority']+':'+str(data['bbox_crs']['CRS']['code'])