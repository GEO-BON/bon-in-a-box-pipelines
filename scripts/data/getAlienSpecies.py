## Returns a txt file with invasive species names from GRIIS data of a country (passed into 'file') ##
import pandas as pd
import re
import os

# Load data (adjust path as needed)
# path = "~/Downloads/GRIIS_mongolia/taxon.txt"
# taxon = pd.read_csv(path, sep='\t')

data = biab_inputs()
taxon_file = data['file']  # file path passed in

taxon = pd.read_csv(taxon_file, sep='\t')

# Extract unique scientific names (drop NAs)
scientific_names = taxon['scientificName'].dropna().unique()

# Function to extract genus and species only
def clean_name(name):
    # Use regex to grab the first two words (genus + species)
    match = re.match(r'^([A-Z][a-z]+)\s([a-z\-]+)', name)
    if match:
        return f"{match.group(1)} {match.group(2)}"
    else:
        # If no match (e.g., a genus only), just return original
        return name.split()[0]  # or return name as is

# Apply cleaning function
cleaned_names = [clean_name(name) for name in scientific_names]

# Remove duplicates if cleaning introduced any
cleaned_names = list(set(cleaned_names))

print(cleaned_names)

# Create output folder if it doesn't exist
os.makedirs(output_folder, exist_ok=True)

# Write cleaned names to file
cleaned_names_path = os.path.join(output_folder, "cleaned_names.txt")
with open(cleaned_names_path, "w") as f:
    f.write(", ".join(cleaned_names))

# Register the file with biab_output
biab_output("cleaned_names", cleaned_names_path)

# with open("cleaned_names.txt", "w") as f:
#     f.write(", ".join(cleaned_names))


