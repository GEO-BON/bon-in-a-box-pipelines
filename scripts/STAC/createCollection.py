import pystac
from stac_builder_utils import *
from datetime import datetime, timezone
from pathlib import Path
import sys

inputs = biab_inputs()
print(f"Inputs: {inputs}")

if None in inputs.values():
    biab_error_stop("All inputs are required. Please provide ensure none of them are null.")

if inputs["collection_name"] == "biab-collection":
    biab_info("No collection name provided, using default 'biab-collection'. Warning: if another collection with the same name exists, it will be overwritten.")

collection_id = inputs["collection_name"]
collection_title = inputs["collection_name"].replace("-", " ").title()

# Create collection
collection = stac_create_collection(collection_id, collection_title, inputs["collection_description"], [-180, -90, 180, 90], "2020-01-01", "2020-12-31", inputs["collection_license"])

output_dir = Path(sys.argv[1])
output_dir.mkdir(parents=True, exist_ok=True)
items = []
dates = []
bboxes = []

# Create items for each GeoTIFF file
for file_path in inputs["tiff_files"]:
    file = Path(file_path)
    if not file.exists():
        print(f"File not found, skipping: {file}")
        continue

    print(f"Processing {file}")
    extracted = extract_date_from_filename(file.name)
    item_datetime = extracted if extracted is not None else datetime.now(timezone.utc)
    dates.append(item_datetime)

    item = stac_create_item(file_path, file, file.stem, item_datetime, collection)
    bboxes.append(item.bbox)

    items.append(item)

if len(items) == 0:
    biab_error_stop("No valid GeoTIFF files found to create a STAC collection.")

# Add items to the collection
collection.add_items(items)
collection.normalize_hrefs(str(output_dir))

# Add a start and end date to the collection's temporal extent based on the items' dates
if len(dates) > 1:
    dates.sort()
    temporal_extent = pystac.TemporalExtent(intervals=[[dates[0], dates[-1]]])
    print(f"Temporal extent set to: {dates[0]} - {dates[-1]}")
else:
    temporal_extent = pystac.TemporalExtent(intervals=[[dates[0], dates[0]]])
    print(f"Temporal extent set to: {dates[0]} - {dates[0]}")

# Add a bounding box to the collection's spatial extent based on the items' bounding boxes
if len(bboxes) > 1:
    min_x = min(bbox[0] for bbox in bboxes)
    min_y = min(bbox[1] for bbox in bboxes)
    max_x = max(bbox[2] for bbox in bboxes)
    max_y = max(bbox[3] for bbox in bboxes)
    spatial_extent_bbox = [min_x, min_y, max_x, max_y]
    print(f"Spatial extent set to: {spatial_extent_bbox}")
else:
    spatial_extent_bbox = bboxes[0]
    print(f"Spatial extent set to: {spatial_extent_bbox}")

spatial_extent = pystac.SpatialExtent(bboxes=[spatial_extent_bbox])

collection_extent = pystac.Extent(spatial=spatial_extent, temporal=temporal_extent)
collection.extent = collection_extent

# Save collection
collection.save(catalog_type=pystac.CatalogType.SELF_CONTAINED)

collection_path = output_dir / f"collection.json"
print(f"Collection written to {collection_path}")

try:
    collection.validate_all()
    print("pystac validation successful")
except Exception as e:
    biab_error_stop(f"pystac validation failed: {e}")

biab_output("stac_collection", str(collection_path))