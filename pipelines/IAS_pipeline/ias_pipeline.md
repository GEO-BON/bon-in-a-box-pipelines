_Author(s): Rachel Mason, Saxbee Affleck, Manuela Gómez-Suárez, Hanno Seebens, Samara Manzin, Melodie McGeoch_

## Introduction
Invasive alien species are a major threat to biodiversity. Reducing the rates of introduction and establishment of invasive species is an important component of Target 6 of the Kunming-Montreal Global Biodiversity Framework (GBF). 

The pipeline compiles national information on alien and invasive species and evaluates patterns across time from their first documented records. It combines national checklist data from the Global Register of Introduced and Invasive Species (GRIIS) with the Alien Species First Records database. 

The pipeline applies the Standardising and Integrating Alien Species data (SInAS) workflow to standradize and merge these source datasets. Species names, locations, habitats, occurrence information and first-record dates are standardized before the GRIIS and First Records data are merged. Species names and taxonomic classifications are checked against the GBIF taxonomic backbone. Records that cannot be fully standardized are documented in the pipeline's data-quality outputs. 

The pipeline creates an annual time series of invasive alien species first records for the selected country. A first record represents the first documented detection of a species; it does not necessarily represent the year that the species was introduced, established, or became invasive.

Depending on first-record completeness and the number of years containing records, the pipeline selects one of four approaches:
- no modelling when the available data are too sparse;
- a qualitative comparison of first-records and GBIF observation patterns;
- a reduced set of quantitative models; or 
- the complete set of quantitative models. 

The quantitative approaches include a naive Poisson model, a constant-detection model, a Solow-Costello model, and a sampling model that uses annual GBIF record volume as an indirect proxy for observation effort. The outputs describe the assumptions, fit, estimated trend, interpretation, and limitations of each model . For ore information about estimating introduction rates from first-record data, see McGeoch et al. (2023) and Buba et al. (2024).

## Uses
This pipeline can be used to:
- Compile and standardize national GRIIS and First Records data to produce a taxonomically standardized national dataset of alien and invasive species.

- Identify unmatched, excluded, or potentially problematic records for data-quality review. 

- Summarize and examine temporal patterns in observed first records.

- Compare models with different assumptions about detectino and observation effort.

- Support national assessment and reporting related to Target 6 of the GBF

## Pipeline limitations
* This pipeline cannot be currently be run for the following countries because of unresolved source-data, checklist-name, or location-mapping issues: United States of America (USA), Belgium (BEL), Thailand (THA), Eswatini (SWZ), Hungary (HUN), and Norway (NOR).

* Annual GBIF record counts are used as an indirect proxy for changing observation effort. GBIF record volume is not a direct measurement of invasive alien species survey effort. 

* Model results must be interpreted with caution, please read the model interpretation outputs and papers listed below for guidance. 

* Automated taxonomic and location standardization cannot resolve every record. Users should review the data-quality, unmatched-value, and excluded-record outputs before interpreting the results. 

* When a first-record date is supplied as a range, the pipeline uses its mean year. This estimated year does not represent a precisely documented date.

* The results depend on the versions and coverage of underlying GRIIS, First Records, GBIF, and configuration data. 

## Before you start
A free GBIF account is required to obtain the GBIF observation data used by the pipeline. Add your GBIf username, password, and account email address to the `runner.env` file using the following environment variables: `GBIF_USER`, `GBIF_PWD`, and `GBIF_EMAIL`.

Users should note the versions of the source databases and workflow used for an analysis. Any modifications to the workflow, configuration tables, or source data should also be reported to support transparency and reproducibility.

Review the unmatched-value, excluded-record, taxonomic-matching, merge-conflict, and other data-quality outputs before interpreting the results.


## Running the pipeline
BON in a Box contains a pipeline to analyze temporal patterns for invasive and alien species for a given country or region of interest. The pipeline has the following user inputs:

### Pipeline inputs

- **Country:** the user must select a country for the Invasive Alien Species analysis. This can be done by selecting a country drom the drop-down menu.   

- **Start year:** the user must select the start year for which to get GBIf observations. The GBIF records will be used as a proxy for sampling effort in a given country. 

- **End year:** the user must select the end year for which to get GBIF observations. These will be used as a proxy for sampling effort in a given country

- **Kingdoms:** the user must select the kingdoms to retain in both the GRIIS and First Records datsets. This can be done by selecting from the available kingdoms in the drop-down menu. 

- **Habitat Types:** the user must select the habitat values to retain in both the GRIIS and First Records datasets. This can be done by selecting a value from the drop-down menu. 

### Pipeline steps
#### **1.  Getting First Records Data**
This step downloads data from the Alien Species First Records database that indicates when an invasive species was first recorded in the user's selected country.

#### **2.  Getting GRIIS Checklist**
This step downloads national checklist data from the Global Register of Introduced and Invasive Species (GRIIS) for the user's selected country.

#### **3. Standardizing and cleaning the datasets**
This step applies the Standardising and Integrating Alien Species data (SInAS) workflow to standardize and clean these source datasets. 

#### **4. Getting GBIF occurrences of species for the country of interest**
This step retrieves data from GBIF using the GBIF API. Users should have a GBIF username, password, and account email address to the runner.env file using the following environment variables: GBIF_USER, GBIF_PWD, and GBIF_EMAIL.

#### **5. Merging the datasets**
This step applies the Standardising and Integrating Alien Species data (SInAS) workflow to merge these datasets. Species names and taxonomic classifications are checked against the GBIF taxonomix backbone. 

#### **6. Analyzing the trends of Invasive Alien Species introduction rates**
This step chooses the appropriate model to calculate the rate of introduction of IAS and survey-effor trenf within the user's selected country. 


### Pipeline outputs

- **SInAS merged dataset:** A dataset that describes the invasive species taxa, its location, and its establishment means from the merged datasets from the GRIIS checklist and the First Records database

- **SInAS data quality report:** The combined quality-control status, unmatched values, and merge conflicts, including the action taken from each issue as a result of merging the data sources.  

- **SInAS excluded records:** The complete source of records excluded from the merging of the data sources that could not be standardised according to the SInAS workflow.

- **SInAS run summary:** The original record counts of invasive species from the GRIIS checklist and the First Records database along with the merged record counts following standardization, cleaning, and quality checks.

- **Model outputs:** The model assumptions, parameters, fit statistics, convergence status, estimated trend direction, interpretation, and caveats for every model option. First-record trends are not automatically equivalent to introduction trends.

- **Modelling decision:** The reasoning behind the model that was reported. This includes the selected data scenario, adequacy criteria, supported level of why the model was chosen, interpretation guidance, shared scope, and the references. 

- **Modelling data summary:** Data-adequacy statistics for the selected country. First-record completeness is the percentage of GRIIS taxa flagged invasive anywhere that have a first-record year, it is not overall checklist completeness. 

- **Quantitative model comparison:** The fitted annual discovery records from models with alternative detection assumptions. Compare fit statistics only among convergedmodels fitted to the same country and time series.

- **Qualitative model plot:** Descriptive comparison of annual IAS first records with the GBIf observation proxy. Similar patterns may indicate an observation-effort effect; this plot is not a a corrected introduction-rate estimate.

- **Qualitative model interpretation:** Interpretation selected from the fitted IAS-observation and survey effort trend combination. A trend is classified as stable when its fitted time slope is not significant at alpha = 0.05. Evidence for and increasing certainty in successful prevention/management (UAS observations: decreasing; survey effort: increasing)

## Example


## Troubleshooting

**Common errors:**

- `401 - Unauthorized` : this error indicates a failure to connect to the GBIF API. This is typically because the GBIF account information provided is not valid. 

## References

Buba, Y. (2024). alien: Estimate Invasive and Alien Species (IAS) Introduction Rates [Dataset]. https://doi.org/10.32614/CRAN.package.alien

Buba, Y., Kiflawi, M., McGeoch, M. A., & Belmaker, J. (2024). Evaluating models for estimating introduction rates of alien species from discovery records. Global Ecology and Biogeography, 33(8), e13859. https://doi.org/10.1111/geb.13859

McGeoch, M. A., Buba, Y., Arlé, E., Belmaker, J., Clarke, D. A., Jetz, W., Li, R., Seebens, H., Essl, F., Groom, Q., García‐Berthou, E., Lenzner, B., Meyer, C., Vicente, J. R., Wilson, J. R. U., & Winter, M. (2023). Invasion trends: An interpretable measure of change is needed to support policy targets. Conservation Letters, 16(6), e12981. https://doi.org/10.1111/conl.12981
  
Seebens, H., & Gómez-Suárez, M. (2025). SInAS: A global dataset of native and alien distributions of alien species [Dataset]. Zenodo. https://doi.org/10.5281/ZENODO.17727120



