import React, { useState, useRef, useEffect } from 'react';
import Select from 'react-select';

import { Result } from "./Result";
import spinner from '../img/spinner.svg';
import { InputFileWithExample } from './InputFileWithExample';

const BonInABoxScriptService = require('bon_in_a_box_script_service');
const yaml = require('js-yaml');
const api = new BonInABoxScriptService.DefaultApi();

export function PipelinePage(props) {
  const [runId, setRunId] = useState();
  const [resultsData, setResultsData] = useState();
  const [httpError, setHttpError] = useState();
  const [pipelineMetadata, setPipelineMetadata] = useState({});
  const [pipelineMetadataRaw, setPipelineMetadataRaw] = useState({});

  // Called when ID changes
  useEffect(() => {
    if (runId) {
      api.getPipelineOutputs(runId, (error, data, response) => {
        if (error) {
          setHttpError(error.toString());
        } else {
          setResultsData(data);
        }
      });
    }
  }, [runId])

 return (
  <>
    <h2>Single script run</h2>
    <PipelineForm 
      pipelineMetadata={pipelineMetadata} setPipelineMetadata={setPipelineMetadata}
      setPipelineMetadataRaw={setPipelineMetadataRaw}
      setRunId={setRunId} 
      setHttpError={setHttpError} />
    {httpError && <p key="httpError" className="error">{httpError}</p>}
    {pipelineMetadataRaw && <pre key="metadata">{pipelineMetadataRaw.toString()}</pre>}
    <PipelineResults key="results" resultsData={resultsData} setHttpError={setHttpError} />
  </>)
}

function PipelineForm(props) {
  const formRef = useRef(null);

  const defaultPipeline = "hard-coded";
  const [pipelineOptions, setPipelineOptions] = useState([]);

  function loadPipelineMetadata(choice) {
    props.setPipelineMetadata(null);
    props.setPipelineMetadataRaw(null);

    var callback = function (error, data, response) {
      if(error) {
        props.setHttpError(error.toString());
      } else {
        props.setPipelineMetadataRaw(data);
        if(data) props.setPipelineMetadata(yaml.load(data));
      }
    };

    api.getPipelineInfo(choice, callback);
  }

  const handleSubmit = (event) => {
    event.preventDefault();

    runScript();
  };

  const runScript = () => {
    props.setRunId(null);

    var callback = function (error, data /*, response*/) {
      if (error) { // Server / connection errors. Data will be undefined.
        data = {};
        props.setHttpError(error.toString());

      } else if (data) { 
        props.setRunId(data);
      } else {
        props.setHttpError("Server returned empty result");
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
         metadata={props.pipelineMetadata} />
      </label>
      <br />
      <input type="submit" disabled={false} value="Run pipeline" />
    </form>
  );
}

function PipelineResults(props) {
  if (props.resultsData) {
    return Object.entries(props.resultsData).map((entry, i) => {
      const [key, value] = entry;

      if (!key.startsWith("Constant@")) {
        let script = key.substring(0, key.indexOf('@'))
        return <DelayedResult key={key} script={script} folder={value} />
      } else {
        return <pre key={key}>{key} : {value}</pre>
      }
    });
  }
  else return null
}

function DelayedResult(props) {
  const [resultData, setResultData] = useState(null)
  const [scriptMetadata, setScriptMetadata] = useState(null)

  useEffect(() => {
    // Script result
    let xhr = new XMLHttpRequest();
    xhr.open("get", "output/" + props.folder + "/output.json");
    xhr.onreadystatechange = function () {
      if (xhr.readyState === 4) {
        setResultData(JSON.parse(xhr.responseText))
      }
    };
    xhr.send();

    // Script metadata
    var callback = function (error, data, response) {
      setScriptMetadata(yaml.load(data))
    };

    api.getScriptInfo(props.script, callback);

  }, [props.folder, props.script]);

  if (resultData) {
    return <Result data={resultData} logs="" metadata={scriptMetadata} />
  }

  return <img src={spinner} className="spinner" alt="Spinner" />
}