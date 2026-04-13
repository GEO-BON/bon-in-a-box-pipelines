import pandas as pd
import os

try:
    raw_data_path = biab_inputs().get("pollinator_parquet")

    df = pd.read_parquet(raw_data_path)
    
    non_pollinator_genera = ["Pyrus", "Prunus", "Theobroma", "Erythranthe", "Giraffa"]
    
    df = df[df["subScientificName"].str.strip().str.lower() != "no name"]
    df = df[df["subScientificName"].str.contains(" ", na=False)]
    
    df["genus"] = df["subScientificName"].str.split().str[0]
    df = df[~df["genus"].isin(non_pollinator_genera)]
    
    species_list = (
        df["subScientificName"]
        .str.strip()
        .str.split()
        .str[:2]
        .str.join(" ")
        .dropna()
        .unique()
        .tolist()
    )

    print(f"Final Cleaned List: {len(species_list)} species.")
    biab_output("taxa", species_list)

except Exception as e:
    print(f"Cleaning Error: {e}")
    if 'biab_error' in globals(): biab_error(str(e))
    else: raise e