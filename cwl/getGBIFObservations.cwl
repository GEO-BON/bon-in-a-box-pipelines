#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this proof of concept:
# cwltool <path/url to cwl file> --envFolder="./env" [optional inputs] --environment="path/to/runner.env"
# envFolder will keep conda environments between runs.
# environment file is necessary when the script requires credentials.

label: GBIF Observations from Download API
doc:
  - "Description:
    Load complete GBIF data from GBIF download API"
  - "Lifecycle tag: LifecycleMetadata(status=CORE, message=null)"
  - "Authors:
    Guillaume Larocque (https://orcid.org/0000-0002-5967-9156)"


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
        taxa: inputs.taxa,
        bbox_crs: inputs.bbox_crs,
        min_year: inputs.min_year,
        max_year: inputs.max_year,
      }, null, 2);
    }
    JSON
    echo "Running in $OUTPUT_LOCATION" | tee -a $log
    echo "Inputs:" | tee -a $log
    cat $OUTPUT_LOCATION/input.json | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $OUTPUT_LOCATION forCWL__getGBIFObservations \
      "
        channels: [conda-forge]
        dependencies: [pygbif, pandas, pyproj]
        name: forCWL__getGBIFObservations
      " /conda-envs $(inputs.condaPackURL) 2>&1 >> $log

    python3 \
      $SCRIPT_STUBS_LOCATION/system/scriptWrapper.py \
      $OUTPUT_LOCATION \
      $SCRIPT_LOCATION/$(inputs.scriptPath) \
      2>&1 | tee -a $log
    scriptExitCode=\${PIPESTATUS[0]}
    echo "Script exited with code $scriptExitCode" | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh forCWL__getGBIFObservations /conda-envs 2>&1 >> $log

    exit "$scriptExitCode"

inputs:
  #################
  # Script inputs #
  #################
  taxa:
    type: string[]
    label: Taxa list
    doc: Comma-separated list of [taxa](https://en.wikipedia.org/wiki/Taxon). Each value could be a species name, order, class, genus, kingdom or family, as long as it is an exact match with the GBIF taxonomic backbone. Individual species can be looked up [on the GBIF website](https://www.gbif.org/species/).
    default: [Acer saccharum, Acer nigrum]

  bbox_crs:
    label: Bounding box and CRS
    doc: Select a bounding box and CRS
    type:
      type: record
      name: crsBBox
      fields:
      - name: CRS
        type:
          name: CRSDefinition
          type: record
          fields:
          - name: unit
            type: string?
          - name: code
            type: int?
          - name: authority
            type: string?
          - name: name
            type: string?
          - name: CRSBboxWGS84
            type: int[]?
          - name: proj4Def
            type: string?
          - name: wktDef
            type: string?
      - name: bbox
        type: float[]

  min_year:
    type: int
    label: minimum year
    doc: Min year observations wanted
    default: 2010

  max_year:
    type: int
    label: maximum year
    doc: Max year observations wanted
    default: 2024



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
    default: data/getGBIFObservations/getGBIFObservations.py

  scripts_root:
    type: Directory?
    doc: Root folder for scripts. Use this to override the image's scripts while debugging.

outputs:
  observations_file:
    type: File
    label: Observations
    doc: Output file with observations
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'output.json')"
      loadContents: true
      outputEval: $(extractOutputFile(self, "observations_file"))

  total_records:
    type: int
    label: Total number of occurrences
    doc: Total number of GBIF occurrences in csv file
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'output.json')"
      loadContents: true
      outputEval: $(parseInt(extractOutput(self, "total_records")))

  gbif_doi:
    type: string
    label: DOI of GBIF download
    doc: DOI of GBIF download. Used for citing downloaded data.
    outputBinding:
      glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'output.json')"
      loadContents: true
      outputEval: $(extractOutput(self, "gbif_doi"))


  logs:
    type: File
    outputBinding:
       glob: "$((inputs.runFolder ? inputs.runFolder.basename + '/' : '') + 'logs.txt')"
