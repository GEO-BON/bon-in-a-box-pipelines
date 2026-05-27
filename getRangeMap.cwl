#!/usr/bin/env cwl-runner
cwlVersion: v1.2
class: CommandLineTool

requirements:
  InlineJavascriptRequirement: {}
  InplaceUpdateRequirement:
    inplaceUpdate: true
  NetworkAccess:
    networkAccess: true
  InitialWorkDirRequirement:
    listing:
      - entry: $(inputs.runFolder)
        writable: true

      # This is the equivalent of a docker mount
      - entry: $(inputs.environment)
        entryname: /runner.env

      - entry: '${ return {"class": "Directory", "basename": "conda-env-yml", "listing": []}; }'
        entryname: /conda-env-yml
        writable: true
  DockerRequirement:
    dockerPull: ghcr.io/geo-bon/bon-in-a-box-pipelines/runner-conda

baseCommand: ["bash", "-c"]
arguments:
  - |
    export CONDA_PKGS_DIRS=/conda-env-yml/pkgs
    export CONDA_ENVS_PATH=/opt/conda/envs:/conda-env-yml/envs
    mkdir -p /conda-env-yml/pkgs /conda-env-yml/envs
    source $(inputs.condaInitialization.path) $(inputs.runFolder.path) data__getRangeMap "
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
    "
    Rscript $(inputs.wrapper.path) $(inputs.runFolder.path) $(inputs.script.path)

inputs:
  runFolder:
    type: Directory
    inputBinding:
      position: 1

  condaInitialization:
    type: File
    default:
      class: File
      path: .server/script-stubs/system/condaEnvironment.sh

  wrapper:
    type: File
    default:
      class: File
      path: .server/script-stubs/system/scriptWrapper.R

  script:
    type: File
    default:
      class: File
      path: scripts/data/getRangeMap.R

  environment:
    type: File
    default:
      class: File
      path: runner.env


outputs:
  logs:
    type: stdout
  output_file:
    type: File
    outputBinding:
       glob: $(inputs.runFolder.path)/output.json

stdout: $(inputs.runFolder.basename)/logs.txt