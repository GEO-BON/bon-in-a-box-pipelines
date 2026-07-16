import re
from datetime import datetime, timezone
from typing import Optional
import pystac
from pystac.extensions.raster import RasterBand
from pystac.extensions.raster import RasterExtension
from pystac.extensions.raster import Statistics
from pystac.extensions.raster import Histogram
from pystac.extensions.projection import ProjectionExtension
import rasterio
from shapely.geometry import Polygon, mapping
from shapely.ops import transform
from pyproj import Transformer
import numpy as np

def parse_date(date_str: str) -> datetime:
    if re.match(r"^\d{4}-\d{1,2}-\d{1,2}$", date_str):
        return datetime.strptime(date_str, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    if re.match(r"^\d{4}\d{2}\d{2}$", date_str):
        return datetime.strptime(date_str, "%Y%m%d").replace(tzinfo=timezone.utc)
    if re.match(r"^\d{4}-\d{1,2}-\d{1,2}T\d{1,2}:\d{1,2}:\d{1,2}Z$", date_str):
        return datetime.strptime(date_str, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    try:
        return datetime.strptime(date_str, "%Y%m%dT%H%M%S").replace(tzinfo=timezone.utc)
    except ValueError:
        pass
    return datetime.strptime(date_str, "%Y-%m-%dT%H:%M:%S.%fZ").replace(tzinfo=timezone.utc)

_DATE_REGEX = re.compile(r"(?P<date>\d{8}T\d{6}|\d{8}|\d{4}-\d{2}-\d{2})")

def extract_date_from_filename(filename: str) -> Optional[datetime]:
    match = _DATE_REGEX.search(filename)
    if match:
        try:
            return parse_date(match.group("date"))
        except ValueError:
            pass
    return None

def stac_create_item(file_path, file_url, name, datetime, collection, properties={}, units=''):

    bbox, bbox_wgs84, footprint, footprint_wgs84, crs, resolution, dtype = get_raster_metadata(file_path)
    stats_dict = get_raster_statistics(file_path, classes = False, render_info={})
    print('Raster stats dict:', stats_dict)
    histogram = Histogram.create(
        count=len(stats_dict['histogram']['counts']),
        min=stats_dict['minimum'],
        max=stats_dict['maximum'],
        buckets=stats_dict['histogram']['counts']
    )
    print('Raster histogram for STAC Item:', histogram)
    statistics = Statistics.create(
        minimum=stats_dict['minimum'],
        maximum=stats_dict['maximum'],
        mean=stats_dict['mean'],
        stddev=stats_dict['stddev'],
        valid_percent=stats_dict['valid_percent']
    )
    print('Raster statistics for STAC Item:', statistics)
    asset = pystac.Asset(
        href=file_url,
        media_type=pystac.MediaType.COG
    )
    raster_bands = [RasterBand.create(
        spatial_resolution=resolution,
        unit=units,
        data_type=dtype,
        statistics=statistics,
        histogram=histogram,
        )
    ]
    raster_ext = RasterExtension.ext(asset)
    raster_ext.bands = raster_bands
    properties['proj:bbox'] = bbox

    item = pystac.Item(id=name,
                      geometry=footprint_wgs84,
                      bbox=bbox_wgs84,
                      datetime=datetime,
                      properties=properties,
                      collection=collection,
                      )

    ProjectionExtension.add_to(item)
    proj_ext = ProjectionExtension.ext(item)
    if (isinstance(crs, int)):
        proj_ext.epsg = crs
    else:
        proj_ext.epsg = None
        proj_ext.wkt2 = crs
    item.set_self_href('./' + collection.id + '/' + name + '.json')

    print('Created STAC Item:', item.to_dict())
    return item


"""
Convert numpy/rasterio dtype to STAC-compliant data type string.

Args:
    dtype: numpy dtype object or string representation of dtype

Returns:
    String representation of data type following STAC Raster Extension spec
    (e.g., 'uint8', 'uint16', 'int16', 'int32', 'float32', 'float64')
"""
def convert_dtype_to_stac(dtype):
    if dtype is None:
        return None

    # If it's already a string, try to normalize it
    if isinstance(dtype, str):
        dtype_str = dtype.lower().strip()
    else:
        # Convert numpy dtype to string
        dtype_str = str(dtype).lower().strip()

    # Map common dtype representations to STAC format
    dtype_mapping = {
        'uint8': 'uint8',
        'uint16': 'uint16',
        'uint32': 'uint32',
        'uint64': 'uint64',
        'int8': 'int8',
        'int16': 'int16',
        'int32': 'int32',
        'int64': 'int64',
        'float16': 'float16',
        'float32': 'float32',
        'float64': 'float64',
        'complex64': 'cfloat32',
        'complex128': 'cfloat64',
        'complex32': 'cfloat32',
    }

    # Remove common prefixes
    dtype_str = dtype_str.replace('numpy.', '').replace('dtype(', '').replace(')', '').replace("'", '').replace('"', '')

    # Return mapped value or original if not found
    return dtype_mapping.get(dtype_str, dtype_str)


def get_raster_metadata(raster_uri):
    with rasterio.open(raster_uri) as ds:
        print('Raster metadata')
        bounds = ds.bounds
        bbox = [bounds.left, bounds.bottom, bounds.right, bounds.top]
        footprint = Polygon([
            [bounds.left, bounds.bottom],
            [bounds.left, bounds.top],
            [bounds.right, bounds.top],
            [bounds.right, bounds.bottom]
        ])
        if (ds.meta['crs'].to_epsg() == None):
            crs=ds.meta['crs'].to_string()
        else:
            crs=ds.meta['crs'].to_epsg()
        project = Transformer.from_crs(crs, 4326, always_xy=True).transform
        ll = project(bounds.left,bounds.bottom)
        ur = project(bounds.right,bounds.top)
        bbox_wgs84 = [ll[0],ll[1],ur[0],ur[1]]
        footprint_wgs84 = transform(project,footprint)
        pixelSizeX, pixelSizeY  = ds.res
        # Convert dtype to STAC-compliant format
        dtype_stac = convert_dtype_to_stac(ds.meta['dtype'])
    return (bbox,bbox_wgs84, mapping(footprint), mapping(footprint_wgs84), crs, pixelSizeX, dtype_stac)

def get_raster_statistics(raster_uri, classes=False, render_info=None):
    """
    Compute raster band statistics following STAC Raster Extension spec.
    Returns a dictionary with minimum, maximum, mean, stddev, and valid_percent.
    """
    with rasterio.open(raster_uri) as ds:
        # Read the first band (assuming single band raster)
        band_data = ds.read(1)
        nodata = ds.nodata
        raster_dtype = ds.meta['dtype']

        # Create a mask for valid pixels (non-nodata)
        if nodata is not None:
            valid_mask = band_data != nodata
        else:
            valid_mask = np.ones_like(band_data, dtype=bool)

        # Exclude NaN/Inf values as well
        finite_mask = np.isfinite(band_data)
        valid_mask = valid_mask & finite_mask

        # Calculate valid percentage based on finite, non-nodata pixels
        total_pixels = band_data.size
        valid_pixels = np.sum(valid_mask)
        valid_percent = (valid_pixels / total_pixels) * 100.0 if total_pixels > 0 else 0.0

        # Calculate statistics on valid pixels only
        valid_data = band_data[valid_mask]

        if valid_data.size > 0:
            # np.min/mean/etc on an empty array would raise; we've ensured it's non-empty
            minimum = float(np.min(valid_data))
            maximum = float(np.max(valid_data))
            mean = float(np.mean(valid_data))
            stddev = float(np.std(valid_data))
            # Guard against non-finite results (shouldn't happen since we masked), set to None if so
            if not np.isfinite(minimum):
                minimum = None
            if not np.isfinite(maximum):
                maximum = None
            if not np.isfinite(mean):
                mean = None
            if not np.isfinite(stddev):
                stddev = None
        else:
            # If no valid pixels, set statistics to None or appropriate defaults
            minimum = None
            maximum = None
            mean = None
            stddev = None

        if classes and (raster_dtype in ['uint8','uint16','uint32','uint64']):
            bins, counts = np.unique(valid_data, return_counts=True)
            bins = bins.tolist()
            counts = counts.tolist()
        else:
            counts, edges = np.histogram(valid_data, bins=10, range=(minimum, maximum))
            counts = counts.tolist()
            bins = edges.tolist()

    statistics = {
        'minimum': minimum,
        'maximum': maximum,
        'mean': mean,
        'stddev': stddev,
        'valid_percent': valid_percent,
        'histogram': {
            'counts': counts,
            'bins': bins
        },
        'region_stats': None
    }
    print('Raster statistics:', statistics)

    return statistics


def stac_create_collection(collection_id, title, description, bbox, start_date, end_date, license):
    """
    Create a STAC Collection with optional multilingual support.

    Args:
        collection_id: Unique identifier for the collection
        title: Default title (typically in English)
        description: Default description (typically in English)
        bbox: Bounding box [minx, miny, maxx, maxy]
        start_date: Start date in ISO format (e.g., "2020-01-01")
        end_date: End date in ISO format (e.g., "2025-12-31")
        license: License identifier (e.g., "CC-0", "CC-BY-4.0")

    Returns:
        pystac.Collection object with multilingual metadata if provided
    """
    spatial_extent = pystac.SpatialExtent(bboxes=[bbox])
    temporal_extent = pystac.TemporalExtent(intervals=[[datetime.fromisoformat(start_date),datetime.fromisoformat(end_date)]])
    collection_extent = pystac.Extent(spatial=spatial_extent, temporal=temporal_extent)
    collection = pystac.Collection(id=collection_id,
                                   title=title,
                                   description=description,
                                   extent=collection_extent,
                                   license=license,
                                   href=collection_id)

    return collection