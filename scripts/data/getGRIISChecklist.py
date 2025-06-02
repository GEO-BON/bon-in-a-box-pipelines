import requests
import time
import json
import csv
import os

input = biab_inputs()

url = "https://api.checklistbank.org/dataset?offset=0&limit=100&q=griis"

print("Accessing Checklist bank to retrieve GRIIS data")
response = requests.get(url)

if response.status_code == 200:
    data = response.json()
    results = data.get("result", [])

    country = input['country']

    # Find dataset(s) where the title contains the country name
    matching = [
        item for item in results
        if country.lower() in item.get("title", "").lower()
    ]

    # Extract the 'key' values
    keys = [item["key"] for item in matching]
    if not keys:
        biab_error_stop("Could not find a GRIIS checklist for your country of interest")

    print(f"Dataset keys for {country}:", keys)
else:
    print(f"Request failed: {response.status_code}")
    biab_error_stop("Failed to retrieve GRIIS checklist")

limit = 100
offset = 0
all_taxa = []
dataset_key = keys[0]

while True:
    url = f"https://api.checklistbank.org/dataset/{dataset_key}/taxon"
    params = {
        "offset": offset,
        "limit": limit
    }

    response = requests.get(url, params=params)
    print(f"Fetching offset {offset}... Status: {response.status_code}")

    if response.status_code != 200:
        print("Error fetching data")
        break

    data = response.json()
    results = data.get("result", [])
    all_taxa.extend(results)

    if data.get("last", False):
        print("Reached last page.")
        break

    offset += limit
    time.sleep(0.2)

# Save to JSON
with open(f"taxa_{dataset_key}.json", "w", encoding="utf-8") as f:
    json.dump(all_taxa, f, indent=2)

print(f"Downloaded {len(all_taxa)} taxa for dataset {dataset_key}")

def flatten_dict(d, parent_key='', sep='_'):
    items = []
    for k, v in d.items():
        new_key = f"{parent_key}{sep}{k}" if parent_key else k
        if isinstance(v, dict):
            items.extend(flatten_dict(v, new_key, sep=sep).items())
        else:
            # Convert lists to comma-separated strings (like authors list)
            if isinstance(v, list):
                v = ', '.join(str(i) for i in v)
            items.append((new_key, v))
    return dict(items)

# Flatten all taxa
flat_taxa = [flatten_dict(taxon) for taxon in all_taxa]

# Collect all fieldnames
fieldnames = set()
for taxon in flat_taxa:
    fieldnames.update(taxon.keys())
fieldnames = sorted(fieldnames)

# Define CSV path
csv_path = os.path.join(output_folder, f"taxa_{dataset_key}.csv")

# Save as CSV
with open(csv_path, "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(flat_taxa)

# Output file
biab_output("checklist", csv_path)

