import json
import logging
import os
from pygbif import occurrences as occ
from pygbif import species as species
import pandas as pd
import time
import zipfile
import requests
import io

data = biab_inputs()

def download_sql(sql,
                 format="SQL_TSV_ZIP",
                 user=None,
                 pwd=None,
                 email=None
                 ):
    url = "https://api.gbif.org/v1/occurrence/download/request"

    header = {
        "accept": "application/json",
        "content-type": "application/json",
        "user-agent": "".join(
            [
                "python-requests/",
                requests.__version__,
                ",pygbif/",
            ]
        ),
    }
    payload = {
        "sendNotification": False,
        "notificationAddresses": [email],
        "format": format,
        "sql": sql
    }

    r = requests.post(
        url,
        auth=requests.auth.HTTPBasicAuth(user, pwd),
        data=json.dumps(payload),
        headers=header,
    )
    if r.status_code > 203:
        raise Exception(
            "error: "
            + r.text
            + ", with error status code "
            + str(r.status_code)
            + "check your number of active downloads."
        )
    else:
        request_id = r.text
        logging.info("Your sql download key is " + request_id)
    return request_id


GBIF_USER=os.environ['GBIF_USER']
GBIF_PWD=os.environ['GBIF_PWD']
GBIF_EMAIL=os.environ['GBIF_EMAIL']

if GBIF_USER=='' or GBIF_PWD=='' or GBIF_EMAIL=='':
		biab_error_stop("Error: GBIF_USER, GBIF_PWD and GBIF_EMAIL environment variable must be defined")

bbox = data['bbox']
#[5.72500000000002, 49.445458984375, 6.49375000000001, 50.1671875]
if bbox=='' or bbox==None or len(bbox)==0:
	biab_error_stop("Please specify bounding box")

splist= data['taxa']
if splist=='' or splist==None or len(splist)==0:
	biab_error_stop("Please specify taxa")

keys=[]
for x in splist:
    print(x)
    try:
        keys.append(species.name_backbone(x)['usageKey'])
        print(species.name_backbone(x)['usageKey'])
    except:
        print(f"Couldn't find a key for {x}, skipping to next species")
        continue
print(keys)
print(f"Starting query for {len(keys)} species")

keys_str = ", ".join(f"'{str(k)}'" for k in keys)

#SQL Query
query = f"""
SELECT "specieskey", MIN("year") AS "gimme"
FROM occurrence
WHERE (
  "decimallongitude" >= {bbox[0]} AND "decimallongitude" <= {bbox[2]} AND
  "decimallatitude" >= {bbox[1]} AND "decimallatitude" <= {bbox[3]} AND
  "specieskey" IN ({keys_str})
)
GROUP BY "specieskey"
"""

#Step 1: Submit download request
print("Submitting GBIF download request...")
download_key = download_sql(query, user=GBIF_USER, pwd=GBIF_PWD, email=GBIF_EMAIL)

#Step 2: Poll until download is ready
print("Waiting for download to complete...")
while True:
    status = occ.download_meta(download_key)['status']
    print(status)
    if status == "SUCCEEDED":
        print("Download complete.")
        meta = occ.download_meta(download_key)
        doi = meta.get("doi", "DOI not available")
        biab_output("gbif_doi", doi)

        break
    elif status == "KILLED" or status == "FAILED":
        biab_error_stop("GBIF download failed or was canceled.")
    time.sleep(20)

#Step 3: Download the ZIP file into memory
url = f"https://api.gbif.org/v1/occurrence/download/request/{download_key}.zip"
print(f"Downloading from: {url}")
response = requests.get(url)
response.raise_for_status()

#Step 4: Unzip and extract CSV from memory
with zipfile.ZipFile(io.BytesIO(response.content)) as zip_file:
    csv_inside_zip = f"{download_key}.csv"
    with zip_file.open(csv_inside_zip) as csv_file:
        df = pd.read_csv(csv_file)

print(f"Number of first records found: {len(df)}")
#Step 5: Save the CSV to disk (as cleaned file)
output_csv = os.path.join(output_folder, "cleaned_data.csv")
df.to_csv(output_csv, index=False)
print(f"Saved cleaned CSV to: {output_csv}")

biab_output("first_record_file", output_csv)

