import React, { useState, useRef, useEffect } from 'react';
import Select from 'react-select';

import { Result } from "./Result";
import { InputFileWithExample } from './InputFileWithExample';
import { FoldableOutput, RenderContext, createContext } from './FoldableOutput'

import { useInterval } from '../UseInterval';

import spinnerImg from '../img/spinner.svg';
import errorImg from '../img/error.svg';
import warningImg from '../img/warning.svg';
import { LogViewer } from './LogViewer';

const BonInABoxScriptService = require('bon_in_a_box_script_service');
const yaml = require('js-yaml');
const api = new BonInABoxScriptService.DefaultApi();

export function PipelinePage(props) {
  const [runId, setRunId] = useState(null);
  const [stoppable, setStoppable] = useState(null);
  const [runningScripts, setRunningScripts] = useState(new Set());
  const [resultsData, setResultsData] = useState(null);
  const [httpError, setHttpError] = useState(null);
  const [pipelineMetadata, setPipelineMetadata] = useState(null);

  function showHttpError(error, response){
    if(response && response.text) 
      setHttpError(response.text)
    else if(error)
      setHttpError(error.toString())
    else 
      setHttpError(null)
  }

  let timeout
  function loadPipelineOutputs() {
    if (runId) {
      api.getPipelineOutputs(runId, (error, data, response) => {
        if (error) {
          showHttpError(error, response)
        } else {
          let allOutputFoldersKnown = Object.values(data).every(val => val !== "")
          if(!allOutputFoldersKnown) { // try again later
            timeout = setTimeout(loadPipelineOutputs, 1000)
          }

          setResultsData(data);
        }
      });
    } else {
      setResultsData(null);
    }
  }

  function showMetadata(){
    if(pipelineMetadata) {
      let yamlString = yaml.dump(pipelineMetadata)
      return <pre key="metadata">{yamlString.startsWith('{}') ? "No metadata" : yamlString}</pre>;
    }
    return ""
  }

  useEffect(() => {
    setStoppable(runningScripts.size > 0)
  }, [runningScripts])

  const stop = () => {
    setStoppable(false)
    api.stopPipeline(runId, (error, data, response) => {
        if(response.status === 200) {
          setHttpError("Cancelled by user")
        }
    })
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
        showHttpError={showHttpError} />
      {runId && <button onClick={stop} disabled={!stoppable}>Stop</button>}
      {httpError && <p key="httpError" className="error">{httpError}</p>}
      {showMetadata()}
      <PipelineResults key="results" resultsData={resultsData} setRunningScripts={setRunningScripts} />
    </>)
}

function PipelineForm({pipelineMetadata, setPipelineMetadata, setRunId, showHttpError}) {
  const formRef = useRef(null);

  const defaultPipeline = "helloWorld.json";
  const [pipelineOptions, setPipelineOptions] = useState([]);

  function clearPreviousRequest() {
    showHttpError(null)
    setRunId(null)
  }

  function loadPipelineMetadata(choice) {
    clearPreviousRequest()
    setPipelineMetadata(null);

    var callback = function (error, data, response) {
      if(error) {
        showHttpError(error, response)
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
        showHttpError(error, response)

      } else if (data) {
        setRunId(data);
      } else {
        showHttpError("Server returned empty result");
      }
    };

    clearPreviousRequest()
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

function PipelineResults({resultsData, setRunningScripts}) {
  const [activeRenderer, setActiveRenderer] = useState({});

  if (resultsData) {
    return <RenderContext.Provider value={createContext(activeRenderer, setActiveRenderer)}>
      {Object.entries(resultsData).map((entry, i) => {
        const [key, value] = entry;

        return <DelayedResult key={key} id={key} folder={value} setRunningScripts={setRunningScripts} />
      })}
    </RenderContext.Provider>
  }
  else return null
}

function DelayedResult({id, folder, setRunningScripts}) {
  const [resultData, setResultData] = useState(null)
  const [scriptMetadata, setScriptMetadata] = useState(null)
  const [running, setRunning] = useState(false)
  const [skipped, setSkipped] = useState(false)

  const script = id.substring(0, id.indexOf('@'))

  useEffect(() => { 
    // A script is running when we know it's folder but have yet no result nor error message
    let nowRunning = folder && !resultData
    setRunning(nowRunning)

    setRunningScripts((oldSet) => {
      let newSet = new Set(oldSet)
      nowRunning ? newSet.add(folder) : newSet.delete(folder)
      return newSet
    })
  }, [setRunningScripts, folder, resultData])

  useEffect(() => {
    if (folder) {
      if(folder === "skipped") {
        setResultData({ warning: "Skipped due to previous failure" })
        setSkipped(true)
      } else if (folder === "cancelled") {
        setResultData({ warning: "Skipped when pipeline stopped" })
        setSkipped(true)
      }
    }
  // Execute only when folder changes (omitting resultData on purpose)
  }, [folder]) 

  const interval = useInterval(() => {
    // Fetch the output
    fetch("output/" + folder + "/output.json")
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

  // Will start when folder has value, and continue the until resultData also has a value
  }, running ? 1000 : null)

  useEffect(() => { // Script metadata
    var callback = function (error, data, response) {
      setScriptMetadata(data)
    };

    api.getScriptInfo(script, callback);
  }, [script]);

  let content, inline = null;
  let className = "foldableScriptResult"
  if (folder) {
    if (resultData) {
      content = <Result data={resultData} metadata={scriptMetadata} />
      if(resultData.error) {
        inline = <img src={errorImg} alt="Error" className="error-inline" />
      } else if(resultData.warning) {
        inline = <>
          <img src={warningImg} alt="Warning" className="error-inline" />
          {skipped && <i>Skipped</i>}
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

  let logsAddress = folder && "output/" + folder + "/logs.txt"

  return (
    <FoldableOutput title={script} componentId={id} inline={inline} className={className}
      description={scriptMetadata && scriptMetadata.description}>
      {content}
      {folder && !skipped && <LogViewer address={logsAddress} autoUpdate={!resultData} />}
    </FoldableOutput>
  )
}