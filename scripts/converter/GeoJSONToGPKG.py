import geopandas as gpd
from pathlib import Path

inputs = biab_inputs()
if "geojson_file" in inputs:
    input_file = inputs["geojson_file"]
    output_type = "gpkg"
    driver = "GPKG"

elif "gpkg_file" in inputs:
    input_file = inputs["gpkg_file"]
    output_type = "geojson"
    driver = "GeoJSON"

else:
    biab_error_stop("No input file provided. Please provide either a GeoJSON or a GeoPackage file.")

name = Path(input_file).stem

# Read the GeoJSON file
gdf = gpd.read_file(input_file)
outfile = ("%s/%s.%s") % (output_folder, name, output_type)

# Write to GeoPackage format
gdf.to_file(outfile, driver=driver)

# Output
biab_output(f"{output_type}_file", outfile)
