import math
import pystac
from stac_builder_utils import *
import subprocess
from datetime import datetime, timezone
from pathlib import Path
import sys

inputs = biab_inputs()

output_dir = Path(sys.argv[1])
output_dir.mkdir(parents=True, exist_ok=True)
items = []
all_band_names = []
spatial_extent_bbox = [float("inf"), float("inf"), -float("inf"), -float("inf")]
temporal_start: Optional[datetime] = None
temporal_end: Optional[datetime] = None

for file_path in inputs["tiff_files"]:
    file = Path(file_path)
    if not file.exists():
        print(f"File not found, skipping: {file}")
        continue

    print(f"Processing {file}")

    cmd = ["gdalinfo", str(file), "-json", "--config", "GDAL_IGNORE_ERRORS", "ALL"]
    out = subprocess.check_output(cmd, timeout=1800, text=True)
    gdalinfo = parse_json_from_output(out)

    coordinates = gdalinfo.get("wgs84Extent", {}).get("coordinates", [])
    if coordinates:
        latlon_bbox = [
            min(c[0] for polygon in coordinates for c in polygon),
            min(c[1] for polygon in coordinates for c in polygon),
            max(c[0] for polygon in coordinates for c in polygon),
            max(c[1] for polygon in coordinates for c in polygon),
        ]
        geometry = {"type": "Polygon", "coordinates": coordinates}
        spatial_extent_bbox = [
            min(spatial_extent_bbox[0], latlon_bbox[0]),
            min(spatial_extent_bbox[1], latlon_bbox[1]),
            max(spatial_extent_bbox[2], latlon_bbox[2]),
            max(spatial_extent_bbox[3], latlon_bbox[3]),
        ]
    else:
        latlon_bbox = None
        geometry = None

    extracted = extract_date_from_filename(file.name)
    item_datetime = extracted if extracted is not None else datetime.now(timezone.utc)
    print(type(extract_date_from_filename(file.name)))
    print(extract_date_from_filename(file.name))

    if temporal_start is None or item_datetime < temporal_start:
        temporal_start = item_datetime
    if temporal_end is None or item_datetime > temporal_end:
        temporal_end = item_datetime
    print("*******")
    print(file.name)

    item = pystac.Item(
        id=file.stem,
        geometry=geometry,
        bbox=latlon_bbox,
        datetime=item_datetime,
        properties={},
    )

    item.add_asset(
        key="data",
        asset=pystac.Asset(
            href=str(file),
            title=file.name,
            media_type=pystac.MediaType.GEOTIFF,
            roles=["data"],
        ),
    )

    items.append(item)

spatial_extent = pystac.SpatialExtent(
    bboxes=[spatial_extent_bbox] if not math.isinf(spatial_extent_bbox[0]) else [[-180, -90, 180, 90]]
)
temporal_extent = pystac.TemporalExtent(intervals=[[temporal_start, temporal_end]])

# how should we name the collection?
collection = pystac.Collection(
    id="biab-collection",
    description="STAC collection",
    extent=pystac.Extent(spatial=spatial_extent, temporal=temporal_extent),
    license="proprietary",
)

collection.add_items(items)
collection.normalize_hrefs(str(output_dir))
collection.save(catalog_type=pystac.CatalogType.SELF_CONTAINED)

collection_path = output_dir / "collection.json"
print(f"Collection written to {collection_path}")

try:
    collection.validate_all()
    print("pystac validation successful")
except Exception as e:
    print(f"pystac validation failed: {e}")

biab_output("stac_collection", str(collection_path))