import { useState } from "react";
import spinner from './img/spinner.svg';
import './App.css';
import RenderedMap from './RenderedMap'

import React, {useRef, useEffect, useContext} from 'react'

import Select from 'react-select';
import RenderedCSV from './csv/RenderedCSV'

const BonInABoxScriptService = require('bon_in_a_box_script_service');
const RequestState = Object.freeze({"idle":1, "working":2, "done":3})
const yaml = require('js-yaml');


const RenderContext = React.createContext();

function App() {
  const [requestState, setRequestState] = useState(RequestState.idle);
  const [resultData, setResultData] = useState();
  const [scriptMetadata, setScriptMetadata] = useState({});

  return (
    <>
      <header className="App-header">
        <h1>BON in a Box v2 pre-pre-pre alpha</h1>
      </header>
      <Form setResultData={setResultData} setRequestState={setRequestState} scriptMetadata={scriptMetadata} setScriptMetadata={setScriptMetadata} />
      <Result data={resultData} metadata={scriptMetadata} requestState={requestState} />
    </>
  );
}

function Form(props) {
  const formRef = useRef(null);

  const defaultScript = "HelloWorld.yml"
  const [scriptFileOptions, setScriptFileOptions] = useState([]);

  function loadScriptMetadata(choice) {
    // TODO: cancel previous pending request?
    props.setRequestState(RequestState.done)
    props.setResultData(null)

    var api = new BonInABoxScriptService.DefaultApi()
    var callback = function (error, data, response) {
      // Generate example input.json
      let inputExamples = {}
      const parsedData = yaml.load(data)
      if (parsedData.inputs) {
        Object.keys(parsedData.inputs).forEach((inputKey) => {
          let input = parsedData.inputs[inputKey]
          if (input) {
            const example = input.example
            inputExamples[inputKey] = example ? example : "..."
          }
        })
      }

      // Update input field
      formRef.current.elements["inputFile"].value = JSON.stringify(inputExamples, null, 2)
      resize(formRef.current.elements["inputFile"])

      props.setScriptMetadata(parsedData)
      props.setResultData({error:error, rawMetadata:data})
    }

    api.getScriptInfo(choice, callback);
  }

  const handleSubmit = (event) => {
    event.preventDefault();

    runScript()
  }

  const runScript = () => {
    props.setRequestState(RequestState.working)
    props.setResultData(null)

    var api = new BonInABoxScriptService.DefaultApi()
    var callback = function (error, data/*, response*/) {
      if(error) { // Server / connection errors. Data will be undefined.
        data = {}
        data.files = {}
        data.files.error = error.toString()

      } else if(data && data.error) { // Errors reported by server
        // Add a preamble if there was not a script-generated error on top
        if(!data.files) data.files = {}
        if(!data.files.error) {
          data.files.error = "An error occured. "
        }
        data.files.error += "Please check logs for details."
      }
      // For script-generated errors, nothing to do

      props.setResultData(data)
      props.setRequestState(RequestState.done)
    };

    let opts = {
      'body': formRef.current.elements["inputFile"].value // String | Content of input.json for this run
    };
    api.runScript(props.scriptMetadata.script, opts, callback);
  }

  /**
   * Automatic horizontal and vertical resizing of textarea
   * @param {textarea} input 
   */
  function resize(input)
  {
    input.style.height = "auto"
    input.style.height = (input.scrollHeight) + "px";

    input.style.width = "auto"
    input.style.width = (input.scrollWidth) + "px";
  }

  // Applied only once when first loaded  
  useEffect(() => {
    // Initial resize of the textarea
    resize(formRef.current.elements["inputFile"])

    // Load list of scripts into scriptFileOptions
    let api = new BonInABoxScriptService.DefaultApi();
    api.scriptListGet((error, data, response) => {
      if (error) {
        console.error(error);
      } else {
        let newOptions = [];
        data.forEach(script => newOptions.push({label: script, value: script}));
        setScriptFileOptions(newOptions)
        loadScriptMetadata(defaultScript)
      }
    });
    // Empty dependency array to get script list only once
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return (
    <form ref={formRef} onSubmit={handleSubmit}>
      <label>
        Script file:
        <br />
        <Select name="scriptFile" className="blackText" options={scriptFileOptions} defaultValue={{ label: defaultScript, value: defaultScript }}
          onChange={(v) => loadScriptMetadata(v.value)} />
      </label>
      <label>
        Content of input.json:
        <br />
        <textarea name="inputFile" className="inputFile" type="text" defaultValue='{&#10;"occurence":"/output/result/from/previous/script",&#10;"intensity":3&#10;}'
          onInput={(e) => resize(e.target)}></textarea>
      </label>
      <br />
      <input type="submit" disabled={props.requestState === RequestState.working} value="Run script" />
    </form>
  );
}

function Result(props) {
  const [activeRenderer, setActiveRenderer] = useState([]);
  
  function toggleVisibility(componentId) {
    setActiveRenderer(activeRenderer === componentId ? null : componentId)
  }

  if(props.requestState === RequestState.idle)
    return null

  if (props.requestState === RequestState.working) 
    return (
      <div>
        <img src={spinner} className="spinner" alt="Spinner" />
      </div>
    );

  let data = props.data
  if(data)
  {
    return (
      <div>
        <RenderContext.Provider value={{data:props.data, metadata:props.metadata, active:activeRenderer}}>
          {data.rawMetadata && <pre key="metadata">{data.rawMetadata.toString()}</pre>}
          <RenderedFiles key="files" files={data.files} toggleVisibility={toggleVisibility} />
          <RenderedLogs key="logs" logs={data.logs} toggleVisibility={toggleVisibility} />
        </RenderContext.Provider>
      </div>
    )
  }

  return null
}

function isRelativeLink(value)
{
  return value.startsWith('/')
}

function FoldableOutput (props) {
  const renderContext = useContext(RenderContext)
  let active = renderContext.active === props.componentId
  const titleRef = useRef(null);

  let title = props.title
  let description = null
  if(renderContext.metadata 
    && renderContext.metadata.outputs 
    && renderContext.metadata.outputs[props.title]) {
      let output = renderContext.metadata.outputs[props.title]
      if(output.label) 
       title = output.label

      if(output.description)
        description = output.description
  }

  useEffect(() => {
    if(active) {
      titleRef.current.scrollIntoView({ block: 'start',  behavior: 'smooth' })
    }
  }, [active]);

  return <>
    <div className="outputTitle">
      <h3 ref={titleRef} onClick={() => props.toggleVisibility(props.componentId)}>
        {active ? <b>–</b> : <b>+</b>} {title}
      </h3>
      {props.inline && (
        isRelativeLink(props.inline) ? (
          active && props.inline && <a href={props.inline} target="_blank" rel="noreferrer">{props.inline}</a>
        ) : (
          !active && props.inline
        )
      )}

    </div>
    {active &&
      <div className="outputContent">
        {description && <p className="outputDescription">{description}</p>}
        {props.children}
      </div>
    }
  </>
}

function RenderedFiles(props) {
  const metadata = useContext(RenderContext).metadata

  function getMimeType(key) {
    if (metadata.outputs
      && metadata.outputs[key]
      && metadata.outputs[key].type) {
      return metadata.outputs[key].type
    }
    return "unknown"
  }

  function renderWithMime(key, content) {
    let [type, subtype] = getMimeType(key).split('/')
    switch (type) {
      case "image":
        // Match many MIME type possibilities for geotiffs
        // Official IANA format: image/tiff; application=geotiff
        // Others out there: image/geotiff, image/tiff;subtype=geotiff, image/geo+tiff
        // See https://github.com/opengeospatial/geotiff/issues/34
        // Plus covering a common typo when second F omitted
        if (subtype && subtype.includes("tif") && subtype.includes("geo")) {
          return <RenderedMap tiff={content} />
        }
        return <img src={content} alt={key} />

      case "text":
        if(subtype === "csv") return <RenderedCSV url={content} delimiter="," />
        if(subtype === "tab-separated-values") return <RenderedCSV url={content} delimiter="&#9;" />
        else return <p>{content}</p>
        
      case "unknown":
        return <>
          <p className="error">Missing mime type in output description</p>
          {// Fallback code to render the best we can. This can be useful if temporary outputs are added when debugging a script.
            isRelativeLink(content) ? (
              // Match for tiff, TIFF, tif or TIF extensions
              content.search(/.tiff?$/i) !== -1 ? (
                <RenderedMap tiff={content} />
              ) : (
                <img src={content} alt={key} />
              )
            ) : ( // Plain text or numeric value
              <p>{content}</p>
            )}
        </>

      default:
        return <p>{content}</p>
    }
  }

  if(props.files) {
    return Object.entries(props.files).map(entry => {
      const [key, value] = entry;

      if(key === "warning" || key === "error") {
        return value && <p key={key} className={key}>{value}</p>
      }

      return (
        <FoldableOutput key={key} title={key} componentId={key} inline={value} toggleVisibility={props.toggleVisibility}>
          {renderWithMime(key, value)}
        </FoldableOutput>
      )
    });
  } else {
    return null
  }
}

function RenderedLogs(props) {
  const myId = "logs"

  if (props.logs) {
    return (
      <FoldableOutput title="Logs" componentId={myId} toggleVisibility={props.toggleVisibility}>
        <pre>{props.logs}</pre>
      </FoldableOutput>
    )
  }
  return null
}

export default App
