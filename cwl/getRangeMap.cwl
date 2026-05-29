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
  EnvVarRequirement:
    envDef:
      CONDA_PKGS_DIRS: /conda-env-yml/pkgs
      CONDA_ENVS_PATH: /opt/conda/envs:/conda-env-yml/envs
      SCRIPT_LOCATION: $(inputs.scripts_root.path)

baseCommand: ["bash", "-c"]
arguments:
  - |
    log=$(inputs.runFolder.basename)/logs.txt
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

    Rscript $(inputs.wrapper.path) $(inputs.runFolder.path) $(inputs.scripts_root.path)/$(inputs.scriptPath) > $(inputs.runFolder.basename)/logs.txt | tee $log

inputs:
  runFolder:
    type: Directory
    inputBinding:
      position: 1

  condaInitialization:
    type: File
    default:
      class: File
      path: ../.server/script-stubs/system/condaEnvironment.sh

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
  logs:
    type: stdout
  output_file:
    type: File
    outputBinding:
       glob: $(inputs.runFolder.path)/output.json

stdout: $(inputs.runFolder.basename)/logs.txt
