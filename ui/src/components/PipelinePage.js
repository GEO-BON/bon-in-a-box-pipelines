import React, { useState, useRef, useEffect } from 'react';
import Select from 'react-select';

import { Result } from "./Result";
import spinner from '../img/spinner.svg';
import { InputFileWithExample } from './InputFileWithExample';

const BonInABoxScriptService = require('bon_in_a_box_script_service');
const yaml = require('js-yaml');

export function PipelinePage(props) {
  const [resultFolder, setResultFolder] = useState();
  const [httpError, setHttpError] = useState();
  const [pipelineMetadata, setPipelineMetadata] = useState({});
  const [pipelineMetadataRaw, setPipelineMetadataRaw] = useState({});

 return (
  <>
    <h2>Single script run</h2>
    <PipelineForm 
      pipelineMetadata={pipelineMetadata} setPipelineMetadata={setPipelineMetadata}
      setPipelineMetadataRaw={setPipelineMetadataRaw}
      setResultFolder={setResultFolder} 
      setHttpError={setHttpError} />
    {httpError && <p key="httpError" className="error">{httpError}</p>}
    {pipelineMetadataRaw && <pre key="metadata">{pipelineMetadataRaw.toString()}</pre>}
    {resultFolder && <pre key="resultFolderTEMP">{resultFolder.toString()}</pre>}
  </>)
}

function PipelineForm(props) {
  const formRef = useRef(null);
  const api = new BonInABoxScriptService.DefaultApi();

  const defaultPipeline = "hard-coded";
  const [pipelineOptions, setPipelineOptions] = useState([]);

  function loadPipelineMetadata(choice) {
    props.setPipelineMetadata(null);
    props.setPipelineMetadataRaw(null);

    var callback = function (error, data, response) {
      if(error) {
        setHttpError(error.toString());
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
    props.setResultFolder(null);

    var callback = function (error, data /*, response*/) {
      if (error) { // Server / connection errors. Data will be undefined.
        data = {};
        props.setHttpError(error.toString());

      } else if (data) { 
        props.setResultFolder(data);
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
