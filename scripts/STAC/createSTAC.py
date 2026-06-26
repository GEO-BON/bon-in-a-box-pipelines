import pystac
from pathlib import Path
import sys

inputs = biab_inputs()
collections = inputs['stac_collections']
output_dir = Path(sys.argv[1])
output_dir.mkdir(parents=True, exist_ok=True)
print("*******")
print(output_dir)
# Create STAC catalog
# generate random id for the catalog

catalog = pystac.Catalog(id="biab-catalog", description="STAC catalog derived from collections in biab")

for collection in collections:
    stac_obj = pystac.read_file(collection)

    try:
        stac_obj.validate_all()
        print(f"STAC collection {stac_obj.id} validation successful")
    except pystac.STACValidationError as e:
        biab_error(f"STAC collection {stac_obj.id} validation failed: {e}")

    # Create add collection to STAC catalog
    catalog.add_child(stac_obj)

# Output STAC catalog
catalog.normalize_hrefs(str(output_dir))
catalog.save(catalog_type=pystac.CatalogType.SELF_CONTAINED)

try:
    catalog.validate_all()
    print("Catalog validation successful")
except pystac.STACValidationError as e:
    biab_error(f"STAC catalog validation failed: {e}")

biab_output("stac_catalog", str(output_dir / "catalog.json"))

