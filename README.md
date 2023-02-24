# BON in a Box 2.0

Mapping Post-2020 Global Biodiversity Framework indicators and their uncertainty.

A Geo BON project, born from a collaboration between Microsoft, McGill, Humbolt institute, Université de Sherbrooke, Université Concordia and Université de Montréal.

## Running the servers locally
Prerequisites : 
 - Git
 - Linux: Docker with Docker Compose installed
 - Windows/Mac: Docker Desktop
 - At least 6 GB of free space (this includes the installation of Docker Desktop)

To run:
1. Clone repository (Windows users: do not clone this in a folder under OneDrive.)
2. Using a terminal, navigate to top-level folder.
3. `docker compose pull`
  - This needs to be re-run everytime the server code changes, or when using git pull if you are not certain.
  - The first execution will be long. The next ones will be shorter or immediate, depending on the changes.
  - Network problems may fail the process. First try running the command again. Intermediate states are saved so not everything will be redone even when there is a failure.
5. Provide an environment file (.env) in the root folder with the following keys
    ```
    # Windows only - path to the root directory of the project with forward slashes
    # such as /c/User/me/biab-2.0
    PWD=

    # Access the planetary computer APIs
    JUPYTERHUB_API_TOKEN=
    DASK_GATEWAY__AUTH__TYPE=
    DASK_GATEWAY__CLUSTER__OPTIONS__IMAGE=
    DASK_GATEWAY__ADDRESS=
    DASK_GATEWAY__PROXY_ADDRESS=

    # Access GBIF API
    GBIF_USER=
    GBIF_PWD=
    GBIF_EMAIL=

    # Access Red List Index
    IUCN_TOKEN=
    ```
6. `docker compose up -d`
7. In browser:
    - http://localhost/ shows the UI
8. `docker compose down` (to stop the server when done) 
9. On Windows, to completely stop the processes, you might have to run `wsl --shutdown`

Servers do not need to be restarted when modifying scripts in the /scripts folder:
- When modifying an existing script, simply re-run the script from the UI and the new version will be executed.
- When adding/renaming/removing scripts, refresh the browser page.

## Running the servers remotely
1. Launch a first instance using the [ansible playbook](https://github.com/GEO-BON/biab-server/tree/main/ansible)
2. Check that the servers run with a browser.
3. Create a .env file on the server, as above.
4. Take dockers down and up to load the .env file (this allows accessing GBIF, etc.)

## Scripts
The scripts perform the actual work behind the scenes. They are located in [/scripts folder](/scripts)

Currently supported : 
 - R v4.1.2
 - Julia v1.8.1
 - Python3 v3.10.6
 - sh

Script lifecycle:
1. Script launched with output folder as a parameter.
2. Script reads input.json to get execution parameters (ex. species, area, data source, etc.)
3. Script performs its task
4. Script generates output.json, containing links to result files, or native values (number, string, etc.)

See [empty R script](/scripts/helloWorld/empty.R) for a minimal script lifecycle example.

### Describing a script
The script description is in a .yml file next to the script. It is necessary for the script to be found and connected to other scripts in a pipeline.

Here is an empty commented sample:
``` yml
script: # script file with extension, such as "myScript.py".
description: # Targetted to those who will interpret pipeline results and edit pipelines.
external_link: # Optional, link to a separate project, github repo, etc.
timeout: # Optional, in minutes. By defaults steps time out after 1h to avoid hung process to consume resources. It can be made longer for heavy processes.

inputs: # 0 to many
  key: # replace the word "key" by a snake case identifier for this input
    label: # Human-readable version of the name
    description: # Targetted to those who will interpret pipeline results and edit pipelines.
    type: # see below
    example: # will also be used as default value

outputs: # 1 to many
  key:
    label: 
    description:
    type:
    example: # optional, for documentation purpose only

references: # 0 to many
  - text: # plain text reference
    doi: # link
```

See [example](/scripts/helloWorld/helloR.yml)

#### Input and output types
Each input and output must declare a type, *in lowercase.* The following file types are accepted:
| File type                    | MIME type to use in the yaml   | UI rendering                 |
| ---------------------------- |------------------------------- |------------------------------|
| CSV                          | text/csv                       | HTML table (partial content) |
| GeoJSON                      | application/geo+json           | Plain text (Map TBD)         |
| GeoPackage                   | application/geopackage+sqlite3 | Link                         |
| GeoTIFF <sup>[1](#io1)</sup> | image/tiff;application=geotiff | Map widget (leaflet)         |
| JPG                          | image/jpg                      | \<img> tag                   |
| Shapefile                    | application/dbf                | Link                         |
| Text                         | text/plain                     | Plain text                   |
| TSV                          | text/tab-separated-values      | HTML table (partial content) |
|                              | (any unknown type)             | Plain text or link           |

The following primitive types are accepted:
| "type" attribute in the yaml   | UI rendering                 |
|--------------------------------|------------------------------|
| boolean                        | Plain text                   |
| float, float[]                 | Plain text                   |
| int, int[]                     | Plain text                   |
| options <sup>[2](#io2)</sup>   | Plain text                   |
| text, text[]                   | Plain text                   |
| (any unknown type)             | Plain text                   |

<a name="io1"></a><sup>1</sup> When used as an output, `image/tiff;application=geotiff` type allows an additionnal `range` attribute to be added with the min and max values that the tiff should hold. This will be used for display purposes.
```yml
map:
  label: My map
  description: Some map that shows bla bla...
  type: image/tiff;application=geotiff
  range: [0.1, 254]
  example: https://example.com/mytiff.tif
```

<a name="io2"></a><sup>2</sup> `options` type requires an additionnal `options` attribute to be added with the available options.
```yml
options_example:
  label: Options example
  description: The user has to select between a fixed number of text options. Also called select or enum. The script receives the selected option as text.
  type: options
  options:
    - first option
    - second option
    - third option
  example: third option
```

### Script validation
The structure of the script description file will be validated on push. To run the validation locally,
- On Windows: Make sure docker is running, then run [validateScripts.bat](/scripts/validateScripts.bat)
- On Linux: Run [validateScripts.sh](/scripts/validateScripts.sh)

This validates that the structure is correct, but not that it is correct. Hence, peer review of the scripts and the description files is mandatory before accepting a pull requests.

### Reporting problems
The output keys `info`, `warning` and `error` can be used to report problems in script execution. They do not need to be described in the `outputs` section of the description. They will be displayed specially in the UI.

Any `error` message will halt the rest of the pipeline.

### Script dependencies
Scripts can install their own dependencies directly (`install.packages` in R, `Pkg.add` in Julia, etc). However, it will need to be reinstalled if the server is deployed on another computer or server.

To pre-compile the dependency in the image, add it to [runners/r-dockerfile](runners/r-dockerfile) or [runners/julia-dockerfile](runners/julia-dockerfile). When the pull request is merged to main, a new image will be available to `docker compose pull` with the added dependencies.

## Pipelines
A pipeline is a collection of steps to acheive the desired processing. Each script becomes a pipeline step.
![image](https://user-images.githubusercontent.com/6223744/211096047-d1d205e3-2f5e-4af6-b8c5-015b002432cb.png)


Pipelines also have inputs and outputs. In order to run, a pipeline needs to specify at least one output (red box in image above). It supports [the same types and UI rendering](#input-and-output-types) as individual scripts, since its inputs are directly fed to the steps, and outputs come from the step outputs.

### Pipeline editor

The pipeline editor allows you to create pipelines by plugging steps together.

The left pane shows the available steps, the right pane shows the canvas.

**To add a step:** drag and drop from the left pane to the canvas.

**To connect steps:** drag to connect an output and an input handle. Input handles are on the left, output handles are on the right.

**To add a constant value:** double-click on any input to add a constant value linked to this input. It is pre-filled with the example value.

**To add an output:** double-click on any *step* output to add a *pipeline* output linked to it, or drag and drop the red box from the left pane and link it manually.

**To delete a step or a pipe:** select it and press the Delete key on your keyboard.

**To make an array out of single value outputs:** if many outputs of the same type are connected to the same input, it will be received as an array by the script. 

<img src="https://user-images.githubusercontent.com/6223744/181106359-c4194411-5789-4e55-84d5-24b9e029398f.png" width="300">

A single value can also be combined with an array of the same type, to produce a single array.

<img src="https://user-images.githubusercontent.com/6223744/181106278-f6db6af5-764a-4775-b196-48feac940eec.png" width="300">

**User inputs:** To provide inputs at runtime, simply leave them unconnected in the pipeline editor. They will be added to the sample input.json file when running the pipeline.

If an input is common to many step, a special user input node can be added to avoid duplication. First, link your nodes to a constant.

<img src="https://user-images.githubusercontent.com/6223744/218197354-8a7bb46d-dbaa-4d7f-ad8d-b4dd521fb28f.png" height="52">

Then, use the down arrow to pop the node's menu. Choose "Convert to user input".

<img src="https://user-images.githubusercontent.com/6223744/218197468-142dcdfb-447f-4076-b6c5-59e8e448b32e.png" height="61">

The node will change as below, and the details will appear on the right pane, along with the other user inputs.

<img src="https://user-images.githubusercontent.com/6223744/218197580-d5e21247-0492-40d7-b527-add323abd6b4.png" height="51">


### Pipeline inputs and outputs
Any **input** with no constant value assigned will be considered a pipeline input and user will have to fill the value.

Add an **output** node linked to a step output to specify that this output is an output of the pipeline. All other unmarked step outputs will still be available as intermediate results in the UI.

![image](https://user-images.githubusercontent.com/6223744/181108988-97d988ca-8f4b-45b1-b4a3-32e90821b68b.png)


### Saving and loading
The editor _does not_ allow you to edit files live on the server. Files need to be committed to the github repo using git.

To load an existing pipeline:
1. Make sure you are up to date using (e.g. `git pull --rebase`).
2. Click "Load from file"
3. Browse to the file on your computer and open it.

To save your modifications:
1. Click save: the content is copied to your clipboard.
2. Make sure you are up to date (e.g. `git pull --rebase`).
3. Remove all the content of the target file.
4. Paste content and save.

To share your modifications, commit and push on a branch using git. Then, create a pull request for that branch through the github UI.

## Developer documentation
The linked content is intended for those developing the microservice infrastructure supporting the pipelines.

[Developer documentation](/README-dev.md)

