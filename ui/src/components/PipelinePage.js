import React, { useState, useRef, useEffect } from 'react';
import Select from 'react-select';

import { Result } from "./Result";
import { InputFileWithExample } from './InputFileWithExample';
import { FoldableOutput, RenderContext, createContext } from './FoldableOutput'

import { useInterval } from '../UseInterval';
import { isVisible } from '../utils/IsVisible';

import spinnerImg from '../img/spinner.svg';
import errorImg from '../img/error.svg';
import warningImg from '../img/warning.svg';

const BonInABoxScriptService = require('bon_in_a_box_script_service');
const yaml = require('js-yaml');
const api = new BonInABoxScriptService.DefaultApi();

export function PipelinePage(props) {
  const [runId, setRunId] = useState(null);
  const [resultsData, setResultsData] = useState(null);
  const [httpError, setHttpError] = useState(null);
  const [pipelineMetadata, setPipelineMetadata] = useState(null);

  let timeout
  function loadPipelineOutputs() {
    if (runId) {
      api.getPipelineOutputs(runId, (error, data, response) => {
        if (error) {
          setHttpError(error.toString() + '\n' + response.text);
        } else {
          let allDone = Object.values(data).every(val => val !== "")
          if(!allDone) { // try again later
            timeout = setTimeout(loadPipelineOutputs, 1000)
          }

          setResultsData(data);
        }
      });
    } else {
      setResultsData(null);
    }
  }

  // Called when ID changes
  useEffect(() => {
    setResultsData(null);
    loadPipelineOutputs()

    return function cleanup() {
      if(timeout) clearTimeout(timeout)
    };
  // Called only when ID changes. Including all deps would result in infinite loop.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [runId])

 return (
  <>
    <h2>Pipeline run</h2>
    <PipelineForm
      pipelineMetadata={pipelineMetadata} setPipelineMetadata={setPipelineMetadata}
      setRunId={setRunId}
      setHttpError={setHttpError} />
    {httpError && <p key="httpError" className="error">{httpError}</p>}
    {pipelineMetadata && <pre key="metadata">{yaml.dump(pipelineMetadata)}</pre>}
    <PipelineResults key="results" resultsData={resultsData} setHttpError={setHttpError} />
  </>)
}

function PipelineForm({pipelineMetadata, setPipelineMetadata, setRunId, setHttpError}) {
  const formRef = useRef(null);

  const defaultPipeline = "HelloWorld.json";
  const [pipelineOptions, setPipelineOptions] = useState([]);

  function clearPreviousRequest() {
    setHttpError(null)
    setRunId(null)
  }

  function loadPipelineMetadata(choice) {
    clearPreviousRequest()
    setPipelineMetadata(null);

    var callback = function (error, data, response) {
      if(error) {
        setHttpError(error.toString() + '\n' + response.text);
      } else if(data) {
        setPipelineMetadata(data);
      }
    };

    api.getPipelineInfo(choice, callback);
  }

  const handleSubmit = (event) => {
    event.preventDefault();

    runScript();
  };

  const runScript = () => {
    var callback = function (error, data , response) {
      if (error) { // Server / connection errors. Data will be undefined.
        data = {};
        setHttpError(error.toString() + '\n' + response.text);

      } else if (data) {
        setRunId(data);
      } else {
        setHttpError("Server returned empty result");
      }
    };

    let opts = {
      'body': formRef.current.elements["inputFile"].value // String | Content of input.json for this run
    };
    api.runPipeline(formRef.current.elements["pipelineChoice"].value, opts, callback);
  };

  // Applied only once when first loaded
  useEffect(() => {
    // Load list of scripts into pipelineOptions
    api.pipelineListGet((error, data, response) => {
      if (error) {
        console.error(error);
      } else {
        let newOptions = [];
        data.forEach(script => newOptions.push({ label: script, value: script }));
        setPipelineOptions(newOptions);
        loadPipelineMetadata(defaultPipeline);
      }
    });
    // Empty dependency array to get script list only once
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <form ref={formRef} onSubmit={handleSubmit}>
      <label>
        Pipeline:
        <br />
        <Select name="pipelineChoice" className="blackText" options={pipelineOptions}
          defaultValue={{ label: defaultPipeline, value: defaultPipeline }}
          onChange={(v) => loadPipelineMetadata(v.value)} />
      </label>
      <label>
        Content of input.json:
        <br />
        <InputFileWithExample defaultValue='{}'
         metadata={pipelineMetadata} />
      </label>
      <br />
      <input type="submit" disabled={false} value="Run pipeline" />
    </form>
  );
}

function PipelineResults(props) {
  const [activeRenderer, setActiveRenderer] = useState({});

  if (props.resultsData) {
    return <RenderContext.Provider value={createContext(activeRenderer, setActiveRenderer)}>
      {Object.entries(props.resultsData).map((entry, i) => {
        const [key, value] = entry;

        if (!key.startsWith("Constant@")) {
          return <DelayedResult key={key} id={key} folder={value} />
        } else {
          return <pre key={key}>{key} : {value}</pre>
        }
      })}
    </RenderContext.Provider>

  }
  else return null
}

function DelayedResult(props) {
  const [resultData, setResultData] = useState(null)
  const [scriptMetadata, setScriptMetadata] = useState(null)

  const [logs, setLogs] = useState("")
  const [logsAutoScroll, setLogsAutoScroll] = useState(true)
  const logsEndRef = useRef()

  const script = props.id.substring(0, props.id.indexOf('@'))

  useEffect(() => {
    if (props.folder && props.folder === "skipped") {
      setResultData({ warning: "Skipped due to previous failure" })
    }
  // Execute only when folder changes (omitting resultData on purpose)
  }, [props.folder]) 

  const interval = useInterval(() => {
    // Fetch the output
    fetch("output/" + props.folder + "/output.json")
      .then((response) => {
        if (response.ok) {
          clearInterval(interval);
          return response.json();
        }

        // Script not done yet: wait for next attempt
        if (response.status === 404) {
          return Promise.resolve(null)
        }

        return Promise.reject(response);
      })
      .then(json => setResultData(json))
      .catch(response => {
        clearInterval(interval);
        setResultData({ error: response.status + " (" + response.statusText + ")" })
      });

    // Fetch the logs
    // TODO: Don't fetch if section is folded.
    let start = new Blob([logs]).size
    fetch("output/" + props.folder + "/logs.txt", {
      headers: { 'range': `bytes=${start}-` },
    })
      .then(response => {
        if (response.ok) {
          return response.text();
        } else if(response.status === 416) { // Range not satifiable
          return Promise.resolve(null) // Wait for next try
        } else {
          return Promise.reject(response)
        }
      })
      .then(responseText => {
        if(responseText) {

          if(logsEndRef.current) {
            let visible = isVisible(logsEndRef.current, logsEndRef.current.parentNode)
            setLogsAutoScroll(visible)
          }

          setLogs(logs + responseText);
        }
      })
      .catch(response => {
        clearInterval(interval);
        setResultData({ error: response.status + " (" + response.statusText + ")" })
      });

  // Will start when folder has value, and continue the until resultData also has a value
  }, props.folder && !resultData ? 1000 : null);

  useEffect(() => { // Script metadata
    var callback = function (error, data, response) {
      setScriptMetadata(data)
    };

    api.getScriptInfo(script, callback);
  }, [script]);

  // Logs auto-scrolling
  useEffect(() => {
    if(logsAutoScroll && logsEndRef.current) {
      logsEndRef.current.scrollIntoView({ block: 'end' })
    }
  }, [logs, logsAutoScroll])

  let content, inline = null;
  let className = "foldableScriptResult"
  if (props.folder) {
    if (resultData) {
      content = <Result data={resultData} metadata={scriptMetadata} />
      if(resultData.error) {
        inline = <img src={errorImg} alt="Error" className="error-inline" />
      } else if(resultData.warning) {
        inline = <>
          <img src={warningImg} alt="Warning" className="error-inline" />
          {props.folder === "skipped" && <i>Skipped</i>}
        </>
      }
    } else {
      content = <p>Running...</p>
      inline = <img src={spinnerImg} alt="Spinner" className="spinner-inline" />
    }
  } else {
    content = <p>Waiting for previous steps to complete.</p>
    className += " gray"
  }

  return (
    <FoldableOutput title={script} componentId={props.id} inline={inline} className={className}
      description={scriptMetadata && scriptMetadata.description}>
      {content}
      {props.folder &&
          <pre className='logs'>{logs}<span ref={logsEndRef}/></pre>
      }
    </FoldableOutput>
  )
}