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

print(f"Extracted {scientific_names.size} values")

# Convert to a plain list of strings
scientific_names = [str(name) for name in scientific_names]

#scientific_names = [name.replace("×", "x") for name in scientific_names]

# Step 1: Remove parentheses content
def remove_parentheses(text):
    result = ''
    skip = 0
    for char in text:
        if char == '(':
            skip += 1
        elif char == ')':
            if skip > 0:
                skip -= 1
        elif skip == 0:
            result += char
    return result

# Step 2: Define allowed characters
def is_valid_word(word):
    for ch in word:
        if not (ch.isalnum() or ch in ('-', '.', '×')):
            return False
    return True

# Step 3: Clean each entry
def clean_entry(entry):
    entry = remove_parentheses(entry)
    words = entry.strip().split()
    return ' '.join(word for word in words if is_valid_word(word))

# Step 4: Apply cleaning, deduplicate, and sort alphabetically
cleaned_names = sorted({clean_entry(name) for name in scientific_names if clean_entry(name)}, key=str.lower)

# Step 5: Join with proper commas
final_text = ', '.join(cleaned_names)

print(f"Now we have {len(cleaned_names)} values")

# Step 6: Write to file
cleaned_names_path = os.path.join(output_folder, "output_file.txt")
with open(cleaned_names_path, "w") as f:
    f.write(final_text)

biab_output("output_file", cleaned_names_path)
biab_output("text_array", cleaned_names)
