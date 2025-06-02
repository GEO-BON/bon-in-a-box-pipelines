import pandas as pd
import os
from collections import defaultdict

# Load data
data = biab_inputs()
taxon_file = data['input_file']
column_name = data['column']
filters = data['filters']

print(f"Reading file and extracting data using filters", filters)

# Read CSV
taxon = pd.read_csv(taxon_file)

if column_name not in taxon.columns:
    biab_error_stop("Column does not exist in file. Please enter a valid column name under 'Column'.")

# Group filters by column
filter_map = defaultdict(set)
for f in filters:
    if ':' not in f:
      biab_error_stop("Invalid input. Please use the proper format under 'Filters'.")
    col, val = map(str.strip, f.split(':', 1))
    filter_map[col].add(val)

# Apply grouped filters
for col, vals in filter_map.items():
    if col not in taxon.columns:
        biab_error_stop("Cannot apply filter to the column because it does not exist in file. Please enter valid column names under 'Filters'.")
    taxon = taxon[taxon[col].isin(vals)]

# Extract column (drop NAs)
scientific_names = taxon[column_name].dropna().unique()

# Deduplicate and convert to list
cleaned_names = list(set(scientific_names))

print(f"Extracted {scientific_names.size} values")

# Write cleaned names to file
cleaned_names_path = os.path.join(output_folder, "output_file.txt")
with open(cleaned_names_path, "w") as f:
    f.write(", ".join(cleaned_names))

biab_output("output_file", cleaned_names_path)

biab_output("text_array", cleaned_names)



