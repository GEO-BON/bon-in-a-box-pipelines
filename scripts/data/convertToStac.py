from datetime import datetime, timezone
import os
import pystac
import rasterio
from rasterio.warp import transform_bounds
from shapely.geometry import box, mapping

data = biab_inputs()
tiff_path = data["tiff"]

with rasterio.open(tiff_path) as src:
    bounds = transform_bounds(src.crs, "EPSG:4326", *src.bounds)
    epsg = src.crs.to_epsg()

minx, miny, maxx, maxy = bounds

item = pystac.Item(
    id=os.path.splitext(os.path.basename(tiff_path))[0],
    geometry=mapping(box(minx, miny, maxx, maxy)),
    bbox=list(bounds),
    datetime=datetime.now(timezone.utc),
    properties={"proj:epsg": epsg}
)

item.add_asset("data", pystac.Asset(
    href=tiff_path,
    media_type=pystac.MediaType.GEOTIFF,
    roles=["data"]
))
output_path = os.path.join(output_folder, "stac_item.json")
with open(output_path, "w") as f:
    import json
    json.dump(item.to_dict(), f, indent=2)

biab_output("stac_item", output_path)