import requests
import json
import os
import pandas as pd
import numpy as np

input = biab_inputs()

checklist = pd.read_csv(input['species'])

dataset_key = input['dataset_key']


res_list = []

checklist["habitat"] = ""
print(len(checklist))

# 3. Loop through the rows by index
for index, row in checklist.iterrows():
    species = row['name_scientificName']
    
    try:
        # Search for species key
        res = requests.get(
            url="https://api.gbif.org/v1/species/search",
            params={"q": species}
        )
        results = res.json().get("results")

        if results:
            species_key = results[0].get("key")
            
            # Fetch habitat profile
            res2 = requests.get(
                url=f"https://api.gbif.org/v1/species/{species_key}/speciesProfiles"
            )
            
            if res2.status_code == 200:
                profiles = res2.json().get("results")
                
                if profiles: 
                    # 4. Assign the habitat value to the specific row
                    habitat_val = profiles[0].get("habitat")
                    checklist.at[index, 'habitat'] = habitat_val
        
        # Optional: Print progress
        print(f"Processed {index+1}/{len(checklist)}: {species}")

    except Exception as e:
        print(f"Error on row {index} ({species}): {e}")

# 5. Save the final result
checklist.to_csv('updated_species.csv', index=False)


print(checklist)

# Define CSV path
csv_path = os.path.join(output_folder, "checklist_filtered.csv")

# Save as CSV
checklist.to_csv(csv_path, index=False)

# Output file
biab_output("habitat", csv_path)


