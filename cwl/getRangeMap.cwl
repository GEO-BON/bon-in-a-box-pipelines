#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

# To run this POC
# 1. checkout the BON in a Box repo
# 2. copy runner.sample.env to runner.env
# 3. cd to the cwl folder
# 4. run:
#   cwltool getRangeMap.cwl --runFolder="../output/cwl/data/getRangeMap" --expert_source="MOL"
#
# To run with default parameters, runner.env must contain IUCN_TOKEN variable.

requirements:
  InlineJavascriptRequirement:
    expressionLib:
      - |
        function extractOutput(outputFiles, inputs, key, isFile) {
          if (!outputFiles || outputFiles.length === 0) return null;
          var obj = JSON.parse(outputFiles[0].contents);
          var value = obj[key];
          if (value === undefined || value === null) return null;
          if (isFile) return { class: "File", location: "file://" + value };
          else return value;
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
            entry: inputs.runFolder,
            writable: true
          },
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
      OUTPUT_LOCATION: /output

baseCommand: ["bash", "-c"]
arguments:
  - |
    log=$(inputs.runFolder.basename)/logs.txt
    rm -f $log
    mkdir -p /conda-env-yml/pkgs /conda-env-yml/envs

    cat > "$(inputs.runFolder.basename)/input.json" <<'JSON'
    ${
      return JSON.stringify({
        "expert_source": inputs.expert_source,
        "species": inputs.species
      }, null, 2);
    }
    JSON
    echo "Running in $(inputs.runFolder.basename)" | tee -a $log
    echo "Inputs:" | tee -a $log
    cat $(inputs.runFolder.basename)/input.json | tee -a $log

    # This script does not really need the conda environment. Switch the comments to test with Conda.
    # source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $(inputs.runFolder.path) rbase 2>&1 >> $log
    source $SCRIPT_STUBS_LOCATION/system/condaEnvironment.sh $(inputs.runFolder.path) data__getRangeMap "
      name: data__getRangeMap
      channels:
        - conda-forge
        - r
      dependencies:
        - r-rjson
        - r-dplyr
        - r-tidyr
        - r-purrr
        - r-sf
        - r-stringr
    " /conda-envs $(inputs.condaPackURL) 2>&1 >> $log

    Rscript \
      $SCRIPT_STUBS_LOCATION/system/scriptWrapper.R \
      $(inputs.runFolder.path) \
      $SCRIPT_LOCATION/$(inputs.scriptPath) \
      2>&1 | tee -a $log
    scriptExitCode=\${PIPESTATUS[0]}
    echo "Script exited with code $scriptExitCode" | tee -a $log

    source $SCRIPT_STUBS_LOCATION/system/condaPackEnvironment.sh data__getRangeMap /conda-envs 2>&1 >> $log

    exit "$scriptExitCode"

inputs:
  runFolder:
    type: Directory
    doc: This folder will contain the input.json, output.json, logs.txt, and any other file saved by the script.
    inputBinding:
      position: 1

  expert_source:
    type:
      type: enum
      symbols:
        - MOL
        - IUCN
        - QC
    inputBinding:
      position: 2
    default: IUCN

  species:
    type: string[]
    inputBinding:
      position: 3
    default: ["Myrmecophaga tridactyla"]

  envFolder:
    type: Directory
    doc: Folder for conda-pack to export environments. This avoids downloading/resolving the environement multiple times.
    default:
      class: Directory
      path: ./envs

  environment:
    type: File?
    doc: BON in a Box runner.env file, necessary for scripts requiring credentials. If not provided, an empty one will be used.

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
    type: File
    outputBinding:
      glob: $(inputs.runFolder.basename)/output.json
      loadContents: true
      outputEval: $(extractOutput(self, inputs, "sf_range_map", true))

  logs:
    type: File
    outputBinding:
       glob: $(inputs.runFolder.basename)/logs.txt

