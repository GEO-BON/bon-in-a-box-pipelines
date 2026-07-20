#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this proof of concept:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: Get species range map
doc:
  - "Description:
    This script downloads the range map of the species according to the expert source chosen."
  - "Lifecycle tag: LifecycleMetadata(status=CORE, message=null)"
  - "Authors:
    Maria Isabel Arce-Plata (https://orcid.org/0000-0003-4024-9268)
    Guillaume Larocque (https://orcid.org/0000-0002-5967-9156)"
  - "References:
    Mammal Diversity Database. (2020). Mammal Diversity Database (Version 1.2) [Data set]. Zenodo. http://doi.org/10.5281/zenodo.4139818

    Map of Life. (2021). Mammal range maps harmonised to the Mammals Diversity Database [Data set]. Map of Life. https://doi.org/10.48600/MOL-48VZ-P413

    IUCN. 2022. The IUCN Red List of Threatened Species. Version 2022-2. Accessed on May 2022. https://www.iucnredlist.org/resources/spatial-data-download

    Ministère de l’Environnement, Lutte contre les changements climatiques, Faune et Parcs. Aires de répartition des mammifères terrestres, des reptiles, des amphibiens et des poissons d'eau douce . Acessed on May 2022. https://www.donneesquebec.ca/recherche/dataset/aires-de-repartition-faune"


requirements:
  InlineJavascriptRequirement:
    expressionLib:
      - |
        function extractOutput(outputFiles, key) {
          if (!outputFiles || outputFiles.length === 0) return null;
          return JSON.parse(outputFiles[0].contents)[key];
        }
        function extractOutputs(outputFiles, key) {
          var value = extractOutput(outputFiles, key, true);
          if (value === undefined || value === null) return null;

          return Array.isArray(value) ? value : [value];
        }
        function extractOutputFile(outputFiles, key) {
          var value = extractOutput(outputFiles, key, true);
          if(value === undefined || value === null) return null;
          return { class: "File", location: "file://" + value };
        }
        function extractOutputFiles(outputFiles, key) {
          var value = extractOutput(outputFiles, key, true);
          if (value === undefined || value === null) return null;

          var filePaths = Array.isArray(value) ? value : [value];
          return filePaths.map(function (filePath) {
            return { class: "File", location: "file://" + filePath };
          });
        }
  InplaceUpdateRequirement:
    inplaceUpdate: true
  NetworkAccess:
    networkAccess: true
  InitialWorkDirRequirement:
    listing: |
      ${
        return [
          {
            entry: inputs.envFolder,
            entryname: "/conda-envs",
            writable: true
          },
          {
            entry: { "class": "Directory", "basename": "conda-env-yml", "listing": [] },
            entryname: "/conda-env-yml",
            writable: true
          }
        ].concat(
          inputs.environment
            ? [{ entry: inputs.environment, entryname: "/runner.env" }]
            : []
        ).concat(
          inputs.runFolder
            ? [{ entry: inputs.runFolder, writable: true }]
            : []
        ).concat( // For debugging, overrides /scripts
          inputs.scripts_root
            ? [{ entry: inputs.scripts_root, entryname: "/scripts" }]
            : []
        );
      }


  DockerRequirement:
    dockerPull: ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl:cwl-poc
    # dockerImageId: conda-cwl-runner-local
    # dockerFile:
    #     $include: ../runners/cwl/conda-cwl-dockerfile

  EnvVarRequirement:
    envDef:
      CONDA_PKGS_DIRS: /conda-env-yml/pkgs
      CONDA_ENVS_PATH: /opt/conda/envs:/conda-env-yml/envs
      SCRIPT_LOCATION: /scripts
      SCRIPT_STUBS_LOCATION: /script-stubs
      USERDATA_LOCATION: /userdata
      OUTPUT_LOCATION: "$(inputs.runFolder ? inputs.runFolder.path : runtime.outdir)"

baseCommand: ["bash", "-c"]
arguments:
  - |
    log=$OUTPUT_LOCATION/logs.txt
    rm -f $log
    mkdir -p /conda-env-yml/pkgs /conda-env-yml/envs

    cat > "$OUTPUT_LOCATION/input.json" <<'JSON'
    ${
      return JSON.stringify({
        species: inputs.species,
        expert_source: inputs.expert_source,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" | tee -a $log
    echo "Inputs:" | tee -a $log
    cat $OUTPUT_LOCATION/input.json | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION forCWL__getRangeMap \
      "
        channels: [conda-forge, r]
        dependencies: [r-rjson, r-dplyr, r-tidyr, r-purrr, r-sf, r-stringr]
        name: forCWL__getRangeMap
      " /conda-envs $(inputs.condaPackURL) 2>&1 >> $log

    Rscript \
      $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \
      $OUTPUT_LOCATION \
      $SCRIPT_LOCATION/$(inputs.scriptPath) \
      2>&1 | tee -a $log
    scriptExitCode=\${PIPESTATUS[0]}
    echo "Script exited with code $scriptExitCode" | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh forCWL__getRangeMap /conda-envs 2>&1 >> $log

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  species:
    type: string[]
    label: species
    doc: Scientific name of the species. Multiple species names can be specified, separated with a comma.
    default: [Myrmecophaga tridactyla]

  expert_source:
    type:
      type: enum
      symbols:
        - MOL
        - IUCN
        - QC
    label: source of expert range map
    doc: >
      Source of the expert range map for the species. The options are:
      Map of Life (MOL), International union for conservation of nature (IUCN) and range maps from the Ministère de l’Environnement du Québec (QC).
    default: IUCN



  ###################
  # Run environment #
  ###################

  envFolder:
    type: Directory
    doc: Folder for conda-pack to export environments. This avoids downloading/resolving the same environement multiple times.
    default:
      class: Directory
      path: ./envs

  runFolder:
    type: Directory?
    doc:
      Optional. This folder will keep the input.json, output.json, logs.txt, and any other file saved by the script.
      If left blank, a temporary folder will be used and discarded after the run.

  environment:
    type: File?
    doc:
      Optional. BON in a Box runner.env file, necessary for scripts requiring credentials.
      If not provided, an empty one will be used.

  #################################################################
  # The following inputs should not be changed in a regular setup #
  #################################################################

  condaPackURL:
    type: string
    doc: Base URL to check for conda-pack environments.
    default: https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/

  scriptPath:
    type: string
    doc: Path to the script, relative to scripts root.
    default: data/getRangeMap.R

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  sf_range_map:
    type: File[]
    label: expert range map
    doc: Polygon with expected area for the species.
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'output.json')"
      loadContents: true
      outputEval: $(extractOutputFiles(self, "sf_range_map"))


  logs:
    type: File
    outputBinding:
       glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'logs.txt')"
