# Developer documentation

## IDE setup

For the global project, Visual Studio Code. Recommended extensions:
- GitLens
- Markdown Preview Mermaid
- Mermaid Markdown Syntax Highlighting

For the script-server (Kotlin code), IntelliJ Idea

## Launching the dockers in development mode
`docker compose -f compose.yml -f compose.dev.yml build`
`docker compose -f compose.yml -f compose.dev.yml up`

This command enables:
- OpenAPI editor at http://localhost/swagger
- UI server automatic React hot-swapping
- Script-server (Kotlin) hot-swapping with ./script-server/hotswap.sh in 
- [http-proxy/conf.d/ngnix.conf](../http-proxy/conf.d/ngnix.conf) will be loaded

## Microservice infrastructure

```mermaid
stateDiagram-v2
    state "script-server" as script
    state "scripts (static)" as scripts
    state "output (static)" as output

    [*] --> ngnix
    ngnix --> ui
    ngnix --> script
    ngnix --> scripts
    ngnix --> output
```

- ui: Front-end
- script-server: Running scripts and pipeline orchestration

In addition to these services, 
- [scripts](../scripts/) folder contains all the scripts that can be run.
- [output](../output/) folder contains all scripts result.

## OpenAPI specification

### Single-script scenario
```mermaid
sequenceDiagram
    ui->>script_server: script/list
    script_server-->>ui: 

    ui->>script_server: script/info
    script_server-->>ui: 

    ui->>script_server: script/run
    script_server->>script: 
    script-->>script_server: output.json
    Note left of ui: Currently 1h timeout.<br/>Using a job id necessary for long operations.
    script_server-->>ui: output + logs
```

### Pipeline scenario
```mermaid
sequenceDiagram
    ui->>pipeline_server: pipeline/list
    pipeline_server-->>ui: 

    ui->>pipeline_server: pipeline/<path>/info
    pipeline_server-->>ui: 

    ui->>pipeline_server: pipeline/<path>/run
    pipeline_server-->>ui: id
    loop For each step
        pipeline_server->>script_server: run
        Note right of script_server: May still have timeout issue
        script_server-->>pipeline_server: output.json (script)
        ui->>pipeline_server: pipeline/<id>/outputs
        pipeline_server-->>ui: output.json (pipeline)
    end

```

### Editing the specification
1. Using http://localhost/swagger, edit the specification.
2. Copy the result to [script-server/api/openapi.yaml](../script-server/api/openapi.yaml)
3. Use [ui/BonInABoxScriptService/generate-client.sh](../ui/BonInABoxScriptService/generate-client.sh) and  [script-server/generate-server-openapitools.sh](../script-server/generate-server-openapitools.sh) to regenerate the client and the server.
4. Merge carefully, not all generated code is to be kept.
5. Implement the gaps.

