from pygbif import occurrences as occ
import pandas as pd
import pycountry
from pathlib import Path
import datetime
import time
from requests.exceptions import RequestException

data = biab_inputs()

country_name = data['country_name']['country']['englishName']
if country_name=='' or country_name==None or len(country_name)==0:
	biab_error_stop("Please specify country name")

country_code = data['country_name']['country']['ISO3']
if country_code=='' or country_code==None or len(country_code)==0:
    biab_error_stop("Please specify country code")

def iso3_to_iso2(iso3):
    # Some BON country records include a version suffix (for example AUS_1).
    normalized_iso3 = str(iso3).strip().upper().split("_", 1)[0]
    if len(normalized_iso3) != 3 or not normalized_iso3.isalpha():
        biab_error_stop(
            f"Invalid ISO3 country code '{iso3}' after normalization"
        )

    country = pycountry.countries.get(alpha_3=normalized_iso3)
    return country.alpha_2 if country else biab_error_stop(
        f"No ISO2 code found for ISO3 country code '{normalized_iso3}'"
    )

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
    "OCCURRENCE"
]

issues = [
    "COORDINATE_INVALID",
    "ZERO_COORDINATE",
    "COORDINATE_OUT_OF_RANGE",
    "COUNTRY_COORDINATE_MISMATCH"
]

results = []
normalized_iso3 = str(country_code).strip().upper().split("_", 1)[0]

def get_gbif_count(year, kingdom_key, maximum_attempts=4):
    """Return one GBIF count, retrying temporary API failures."""
    for attempt in range(1, maximum_attempts + 1):
        try:
            return occ.search(
                year=year,
                country=iso2,
                kingdomKey=kingdom_key,
                basisOfRecord=basis_of_record,
                hasCoordinate=True,
                issue=issues,
                limit=0,
                timeout=120,
            )["count"]
        except RequestException as error:
            response = getattr(error, "response", None)
            status_code = getattr(response, "status_code", None)
            retryable = (
                status_code is None
                or status_code == 429
                or 500 <= status_code <= 599
            )

            if not retryable or attempt == maximum_attempts:
                message = (
                    "GBIF count request failed for "
                    f"year {year}, kingdom key {kingdom_key}, after "
                    f"{attempt} attempt(s): {error}"
                )
                biab_error_stop(message)
                raise RuntimeError(message)

            wait_seconds = 5 * (2 ** (attempt - 1))
            print(
                "Temporary GBIF error for "
                f"year {year}, kingdom key {kingdom_key} "
                f"(attempt {attempt}/{maximum_attempts}, "
                f"HTTP {status_code or 'connection error'}). "
                f"Retrying in {wait_seconds} seconds..."
            )
            time.sleep(wait_seconds)

for year in range(start_year, end_year + 1):
    print(f"Getting GBIF counts for {year}...")
    # The two kingdoms are disjoint, so summing these smaller requests is
    # equivalent to the SQL condition kingdom IN ('Animalia', 'Plantae').
    count = sum(get_gbif_count(year, kingdom_key) for kingdom_key in (1, 6))

    results.append({"year": year, "RecordsCount": count})

gbif_country_observations = pd.DataFrame(results)

print(gbif_country_observations)
path = Path(output_folder) / "gbif_country_observations.csv"

gbif_country_observations.to_csv(path, index=False)

biab_output("gbif_country_observations", str(path))
