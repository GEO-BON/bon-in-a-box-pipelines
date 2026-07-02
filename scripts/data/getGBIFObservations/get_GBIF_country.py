from pygbif import occurrences as occ
import pandas as pd
import pycountry
from pathlib import Path
import datetime

data = biab_inputs()

country_name = data['country_name']['country']['englishName']
if country_name=='' or country_name==None or len(country_name)==0:
	biab_error_stop("Please specify country name")

country_code = data['country_name']['country']['ISO3']
if country_code=='' or country_code==None or len(country_code)==0:
    biab_error_stop("Please specify country code")

def iso3_to_iso2(iso3):
    country = pycountry.countries.get(alpha_3=iso3.upper())
    return country.alpha_2 if country else biab_error_stop("No ISO2 code found for the provided ISO3 code")

iso2=iso3_to_iso2(country_code)
print(iso2)

start_year = data['start_year']
if start_year is None or start_year == '':
    biab_error_stop("Please specify start year")
start_year = int(start_year)

end_year = data['end_year']
if end_year is None or end_year == '':
    biab_error_stop("Please specify end year")
end_year = int(end_year)

if end_year < 0:
    biab_error_stop("Please specify a valid end year")

if end_year < start_year:
    biab_error_stop("End year must be greater than or equal to start year")

basis_of_record = [
    "OBSERVATION",
    "LIVING_SPECIMEN",
    "MATERIAL_SAMPLE",
    "HUMAN_OBSERVATION",
    "MACHINE_OBSERVATION",
    "OCCURRENCE",
]

results = []

for year in range(start_year, end_year + 1):
    count = occ.search(
        year=year,
        country=iso2,                     # 2-letter GBIF country code
        kingdomKey=[1, 6],                 # Animalia = 1, Plantae = 6
        basisOfRecord=basis_of_record,     # pygbif repeats this param for OR logic
        occurrenceStatus="PRESENT",
        hasCoordinate=True,                # decimalLongitude/Latitude IS NOT NULL
        hasGeospatialIssue=False,          # excludes COORDINATE_INVALID, ZERO_COORDINATE, etc.
        limit=0,
    )["count"]

    results.append({"year": year, "RecordsCount": count})

gbif_country_observations = pd.DataFrame(results)

print(gbif_country_observations)
path = Path(output_folder) / "gbif_country_observations.csv"

gbif_country_observations.to_csv(path, index=False)

biab_output("gbif_country_observations", str(path))
