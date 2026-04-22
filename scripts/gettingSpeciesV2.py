import os
import sys
import tempfile
import urllib.request
import zipfile
import pandas as pd  
from pyproj import Proj
import gc  

def get_biab_input(key, default):
    try: return biab_inputs().get(key, default) if 'biab_inputs' in globals() else default
    except: return default

def get_zip_path(z, filename):
    matches = [m for m in z.namelist() if m.endswith(filename)]
    return matches[0] if matches else None

zenodo_url = get_biab_input("zenodo_url", "https://zenodo.org/record/14640564/files/dwca.zip")

# Output directory
output_folder = sys.argv[1] if len(sys.argv) > 1 else "/tmp"
os.makedirs(output_folder, exist_ok=True)
parquet_output = os.path.join(output_folder, "raw_interactions.parquet")

# Use a writable temporary directory and ensure it exists
tmp_dir = tempfile.gettempdir()
if not os.path.isdir(tmp_dir):
    tmp_dir = output_folder
os.makedirs(tmp_dir, exist_ok=True)
local_zip = os.path.join(tmp_dir, "dwca.zip")

# Bounding box
bbox_crs = get_biab_input('bbox_crs', None)

if bbox_crs and 'bbox' in bbox_crs and 'CRS' in bbox_crs:
    bbox = bbox_crs['bbox']
    proj_string = bbox_crs['CRS']['authority'] + ':' + str(bbox_crs['CRS']['code'])
    
    myProj = Proj(proj_string)
    lon1, lat1 = myProj(bbox[0], bbox[1], inverse=True)
    lon2, lat2 = myProj(bbox[2], bbox[3], inverse=True)
    
    bbox_min_lon, bbox_max_lon = min(lon1, lon2), max(lon1, lon2)
    bbox_min_lat, bbox_max_lat = min(lat1, lat2), max(lat1, lat2)
else:
    bbox_min_lon, bbox_max_lon = -180.0, 180.0
    bbox_min_lat, bbox_max_lat = -90.0, 90.0

VALID_TYPES = frozenset([
    b'http://purl.obolibrary.org/obo/RO_0002455',
    b'http://purl.obolibrary.org/obo/RO_0002622'
])

try:
    print(f"Downloading {zenodo_url}.", flush=True)
    urllib.request.urlretrieve(zenodo_url, local_zip)

    relevant_occ_hashes = set()
    # Taxon ID -> scientific name
    taxon_name_map = {}
    # Store lat long taxon ID for all occurrences
    occurrence_records = []
    skipped_lines = 0
    spatial_skips = 0

    print("Opening ZIP for raw byte-stream processing.", flush=True)
    with zipfile.ZipFile(local_zip, 'r') as z:

        # occurrence ID hashes for relevant associations
        assoc_path = get_zip_path(z, 'association.tsv')
        if assoc_path:
            print(f"Streaming {assoc_path}.", flush=True)
            with z.open(assoc_path) as f:
                header = next(f).rstrip(b'\r\n').split(b'\t')
                try:
                    occ_idx  = header.index(b'occurrenceID')
                    type_idx = header.index(b'associationType')
                except ValueError:
                    raise ValueError("Missing required columns in association.tsv")

                max_idx = max(occ_idx, type_idx) + 1

                for line in f:
                    parts = line.rstrip(b'\r\n').split(b'\t', max_idx)
                    try:
                        if parts[type_idx] in VALID_TYPES:
                            relevant_occ_hashes.add(hash(parts[occ_idx]))
                    except IndexError:
                        skipped_lines += 1

        print(f"Found {len(relevant_occ_hashes):,} relevant occurrence IDs")

        # save data for relevant occurrences
        occ_path = get_zip_path(z, 'occurrence.tsv')
        if occ_path:
            print(f"Streaming {occ_path}.", flush=True)
            with z.open(occ_path) as f:
                header = next(f).rstrip(b'\r\n').split(b'\t')
                try:
                    occ_idx = header.index(b'occurrenceID')
                    tax_idx = header.index(b'taxonID')
                    lat_idx = header.index(b'decimalLatitude')
                    lon_idx = header.index(b'decimalLongitude')
                except ValueError:
                    raise ValueError("Missing required columns in occurrence.tsv")

                max_idx = max(occ_idx, tax_idx, lat_idx, lon_idx) + 1

                for line in f:
                    parts = line.rstrip(b'\r\n').split(b'\t', max_idx)
                    try:
                        if hash(parts[occ_idx]) in relevant_occ_hashes:
                            try:
                                lat = float(parts[lat_idx])
                                lon = float(parts[lon_idx])

                                if (bbox_min_lat <= lat <= bbox_max_lat) and (bbox_min_lon <= lon <= bbox_max_lon):
                                    occurrence_records.append((lat, lon, hash(parts[tax_idx])))
                                else:
                                    spatial_skips += 1
                            except ValueError:
                                spatial_skips += 1
                    except IndexError:
                        skipped_lines += 1

        del relevant_occ_hashes
        gc.collect()

        print(f"Retained {len(occurrence_records):,} occurrence records within bounding box")
        print(f"Filtered out {spatial_skips:,} occurrences spatially")

        # Collect the taxon ID hashes we actually need
        needed_taxon_hashes = set(r[2] for r in occurrence_records)

        # hash -> scientific name
        taxa_path = get_zip_path(z, 'taxa.tsv')
        if taxa_path:
            print(f"Streaming {taxa_path}.", flush=True)
            with z.open(taxa_path) as f:
                header = next(f).rstrip(b'\r\n').split(b'\t')
                try:
                    tax_idx  = header.index(b'taxonID')
                    name_idx = header.index(b'scientificName')
                except ValueError:
                    raise ValueError("Missing required columns in taxa.tsv")

                max_idx = max(tax_idx, name_idx) + 1

                for line in f:
                    parts = line.rstrip(b'\r\n').split(b'\t', max_idx)
                    try:
                        h = hash(parts[tax_idx])
                        if h in needed_taxon_hashes:
                            name = parts[name_idx].decode('utf-8').strip()
                            if name:
                                taxon_name_map[h] = name
                    except IndexError:
                        skipped_lines += 1

        print(f"Resolved {len(taxon_name_map):,} unique scientific names")

    if skipped_lines > 0:
        print(f"Warning: {skipped_lines:,} malformed lines skipped.", flush=True)

    # output dataframe
    if len(occurrence_records) == 0:
        print("No organisms found in the specified bounding box. Generating an empty Parquet file.", flush=True)
        df = pd.DataFrame({
            'decimalLatitude':    pd.Series(dtype='float64'),
            'decimalLongitude':   pd.Series(dtype='float64'),
            'subScientificName':  pd.Series(dtype='string'),
        })
    else:
        print("Building output dataframe.", flush=True)
        rows = [
            {
                'decimalLatitude':   lat,
                'decimalLongitude':  lon,
                'subScientificName': taxon_name_map.get(tax_hash, ''),
            }
            for lat, lon, tax_hash in occurrence_records
        ]
        df = pd.DataFrame(rows)
        df['subScientificName'] = df['subScientificName'].astype('string')
        # Drop rows where name could not be resolved
        df = df[df['subScientificName'] != ''].reset_index(drop=True)

    print(f"Final parquet rows: {len(df):,}")
    df.to_parquet(parquet_output, index=False)
    
    if 'biab_output' in globals():
        biab_output("pollinator_parquet", parquet_output)
        
    print("Success.")

except Exception as e:
    print(f"Error: {e}")
    if 'biab_error_stop' in globals(): biab_error_stop(str(e))
    elif 'biab_error' in globals(): biab_error(str(e))
    else: raise e

finally:
    if os.path.exists(local_zip):
        os.remove(local_zip)