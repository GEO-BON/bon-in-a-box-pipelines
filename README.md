# BON in a Box 2.0

Mapping Post-2020 Global Biodiversity Framework indicators and their uncertainty.

A GEO BON project, born from a collaboration between Microsoft, McGill, Humbolt institute, Université de Sherbrooke, Université Concordia and Université de Montréal.

## Contributing
If you wish to contribute your indicator or EBV code, please let us know at web@geobon.org.

The recommended method is to setup an instance of BON in a Box somewhere you can easily play with the script files, using the local or remote setup below. You can create a fork to save your work. Make sure that the code is general, and will work when used with various parameters, such as in different regions around the globe. Once the integration of the new scripts or pipelines are complete, open a pull request to this repository. The pull request will be peer-reviewed before acceptation.

## Running the servers locally
Prerequisites : 
 - Git
 - Linux: Docker with Docker Compose installed. It is recommended to [add your user to the docker group](https://docs.docker.com/engine/install/linux-postinstall/).
 - Windows/Mac: Docker Desktop
 - At least 6 GB of free space (this includes the installation of Docker Desktop)
 - RAM requirements will depend on the scripts that you run.

To run:
1. Clone repository (Windows users: do not clone this in a folder under OneDrive.)
2. Using a terminal, navigate to top-level folder.
3. `docker compose pull`
  - This needs to be re-run everytime the server code changes, or when using git pull if you are not certain.
  - The first execution will be long. The next ones will be shorter or immediate, depending on the changes.
  - Network problems may fail the process. First try running the command again. Intermediate states are saved so not everything will be redone even when there is a failure.
  - Windows users may need to turn on virtualization and other tools for Docker Desktop to work and update wsl ("wsl --update", see [https://docs.docker.com/desktop/troubleshoot/topics/#virtualization](https://docs.docker.com/desktop/troubleshoot/topics/#virtualization) and access to the BIOS may be required to enable virtualization)
4. Provide an environment file (.env) in the root folder with the following keys
    ```
    # Windows only - path to the root directory of the project with forward slashes
    # Uncomment line and specify path with forward slashes such as PWD=/c/User/me/biab-2.0
    #PWD=

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

    # Script server cache option: 
    # - full: when a script file changes, all related caches are cleared.
    # - partial: when a script file changes, cache is only overriden when running with the same inputs. 
    # NB: applied on next docker compose up
    SCRIPT_SERVER_CACHE_CLEANER=full

    ```
5. `docker compose up -d`
6. In browser:
    - http://localhost/ shows the UI
7. `docker compose down` (to stop the server when done) 
8. On Windows, to completely stop the processes, you might have to run `wsl --shutdown`

When modifying scripts in the /scripts folder, servers do not need to be restarted:
- When modifying an existing script, simply re-run the script from the UI and the new version will be executed.
- When adding or renamin scripts, refresh the browser page.

When modifying pipelines in the /pipelines folder, servers do not need to be restarted:
- In the pipeline editor, click save, paste the file to your file in the pipeline folder and run it from the "pipeline run" page.
- When adding or renaming pipelines, refresh the browser page.

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
1. Script launched with output folder as a parameter. (In R, an `outputFolder` variable in the R session. In Julia, Shell and Python, the output folder is received as an argument.)
3. Script reads input.json to get execution parameters (ex. species, area, data source, etc.)
4. Script performs its task
5. Script generates output.json, containing links to result files, or native values (number, string, etc.)

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
    example: # will also be used as default value, can be null

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
Each input and output must declare a type, *in lowercase.* It can be a primitive or a file.

The following primitive types are accepted:
| "type" attribute in the yaml   | UI rendering                 |
|--------------------------------|------------------------------|
| boolean                        | Plain text                   |
| float, float[]                 | Plain text                   |
| int, int[]                     | Plain text                   |
| options <sup>[2](#io2)</sup>   | Plain text                   |
| text, text[]                   | Plain text                   |
| (any unknown type)             | Plain text                   |

Any [MIME type](https://en.wikipedia.org/wiki/Media_type) is accepted. Here are a few common ones:
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

Search the web to find the appropriate MIME type for your content. Here are a few references:
- http://www.iana.org/assignments/media-types/media-types.xhtml
- http://svn.apache.org/viewvc/httpd/httpd/trunk/docs/conf/mime.types?view=markup

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
The syntax and structure of the script description file will be validated on push. To run the validation locally,
- On Windows: Make sure docker is running, then run [validateScripts.bat](/scripts/validateScripts.bat)
- On Linux: Run [validateScripts.sh](/scripts/validateScripts.sh)

This validates that the syntax and structure are correct, but not that it's content is correct. Hence, peer review of the scripts and the description files is mandatory before accepting a pull requests.

### Reporting problems
The output keys `info`, `warning` and `error` can be used to report problems in script execution. They do not need to be described in the `outputs` section of the description. They will be displayed specially in the UI.

Any `error` message will halt the rest of the pipeline.

### Script dependencies
Scripts can install their own dependencies directly (`install.packages` in R, `Pkg.add` in Julia, etc). However, it will need to be reinstalled if the server is deployed on another computer or server.

To pre-compile the dependency in the image, add it to [runners/r-dockerfile](runners/r-dockerfile) or [runners/julia-dockerfile](runners/julia-dockerfile). When the pull request is merged to main, a new image will be available to `docker compose pull` with the added dependencies.

### Receiving inputs
When running a script, a folder is created for each given set of parameters. The same parameters result in the same folder, different parameters result in a different folder. The inputs for a given script are saved in an `input.json` file in this unique run folder.

The file contains the id of the parameters that were specified in the yaml script description, associated to the values for this run. Example:
```json
{
    "fc": ["L", "LQ", "LQHP"],
    "method_select_params": "AUC",
    "n_folds": 2,
    "orientation_block": "lat_lon",
    "partition_type": "block",
    "predictors": [
        "/output/data/loadFromStac/6af2ccfcd4b0ffe243ff01e3b7eccdc3/bio1_75548ca61981-01-01.tif",
        "/output/data/loadFromStac/6af2ccfcd4b0ffe243ff01e3b7eccdc3/bio2_7333b3d111981-01-01.tif"
    ],
    "presence_background": "/output/SDM/setupDataSdm/edb9492031df9e063a5ec5c325bacdb1/presence_background.tsv",
    "proj": "EPSG:6623",
    "rm": [0.5, 1.0, 2.0]
}
```

The script reads and uses inputs from the `input.json` file. Example in R:

``` R
## Receiving arguments from input.json.
## outputFolder is already defined by server
library("rjson")
input <- fromJSON(file=file.path(outputFolder, "input.json"))

## Can now be accessed from the map
print(input$predictors)
```

The script should perform appropriate parameter validation.

Note that the inputs will be `null` if the user left the text box empty. 

### Generating outputs
The output files generated by the script must be saved in the run folder. The script must also generate an `output.json` file in the same folder, that contains a map associating the output ids to their values. Example:

```json
{
  "sdm_pred": "/output/SDM/runMaxent/b5937ba69418b65cae7c6cfcfa78b5e8/sdm_pred.tif",
  "sdm_runs":[
    "/output/SDM/runMaxent/b5937ba69418b65cae7c6cfcfa78b5e8/sdm_runs_1.tif",
    "/output/SDM/runMaxent/b5937ba69418b65cae7c6cfcfa78b5e8/sdm_runs_2.tif"
  ]
}
```


## Pipelines
A pipeline is a collection of steps to acheive the desired processing. Each script becomes a pipeline step.
![image](https://user-images.githubusercontent.com/6223744/211096047-d1d205e3-2f5e-4af6-b8c5-015b002432cb.png)


Pipelines also have inputs and outputs. In order to run, a pipeline needs to specify at least one output (rightmost red box in image above). Pipeline IO supports [the same types and UI rendering](#input-and-output-types) as individual steps, since its inputs are directly fed to the steps, and outputs come from the step outputs.

### Pipeline editor
The pipeline editor allows you to create pipelines by plugging steps together.

The left pane shows the available steps, the right pane shows the canvas.

**To add a step:** drag and drop from the left pane to the canvas. Steps that are single scripts will display with a single border, while steps that are pipelines will display with a double border.

![image](https://github.com/GEO-BON/biab-2.0/assets/6223744/f590bd01-d333-4712-934b-242a0f925f58)


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

