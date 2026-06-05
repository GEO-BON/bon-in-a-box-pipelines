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
    listing:
      - entry: $(inputs.runFolder)
        writable: true

      - entry: $(inputs.envFolder)
        writable: true

      # This is the equivalent of a docker mount
      - entry: $(inputs.environment)
        entryname: /runner.env

      - entry: '${ return {"class": "Directory", "basename": "conda-env-yml", "listing": []}; }'
        entryname: /conda-env-yml
        writable: true

  DockerRequirement:
    dockerPull: ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda-cwl

  EnvVarRequirement:
    envDef:
      CONDA_PKGS_DIRS: /conda-env-yml/pkgs
      CONDA_ENVS_PATH: /opt/conda/envs:/conda-env-yml/envs
      SCRIPT_LOCATION: $(inputs.scripts_root.path)

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
    cat $(inputs.runFolder.basename)/input.json | tee -a $log

    # This script does not really need the conda environment. Switch the comments to test with Conda.
    # source $(inputs.condaInitializationScript.path) $(inputs.runFolder.path) rbase 2>&1 >> $log
    source $(inputs.condaInitializationScript.path) $(inputs.runFolder.path) data__getRangeMap "
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
    " $(inputs.envFolder.path) $(inputs.condaPackURL) 2>&1 >> $log

    Rscript \
      $(inputs.wrapper.path) \
      $(inputs.runFolder.path) \
      $(inputs.scripts_root.path)/$(inputs.scriptPath) \
      2>&1 | tee -a $log
    scriptExitCode=\${PIPESTATUS[0]}
    echo "Script exited with code $scriptExitCode" | tee -a $log

    source $(inputs.condaPackScript.path) data__getRangeMap $(inputs.envFolder.path) 2>&1 >> $log

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


  ##############################################
  # The following inputs should not be changed #
  ##############################################

  envFolder:
    type: Directory
    doc: Folder for conda-pack to export environments. This avoids resolving the environement multiple times.
    default:
      class: Directory
      path: ./envs

  condaInitializationScript:
    type: File
    default:
      class: File
      path: ../.server/script-stubs/system/condaEnvironment.sh

  condaPackScript:
    type: File
    default:
      class: File
      path: ../.server/script-stubs/system/condaPackEnvironment.sh

  condaPackURL:
    type: string
    doc: Base URL to check for conda-pack environments.
    default: https://object-arbutus.alliancecan.ca/swift/v1/3857940e33774dca8ae21e4999fe402e/conda-pack/

  wrapper:
    type: File
    default:
      class: File
      path: ../.server/script-stubs/system/scriptWrapper.R

  scriptPath:
    type: string
    doc: Path to the script, relative to scripts_root.
    default: data/getRangeMap.R

  scripts_root:
    type: Directory
    default:
      class: Directory
      path: ../scripts

  environment:
    type: File
    default:
      class: File
      path: ../runner.env


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

