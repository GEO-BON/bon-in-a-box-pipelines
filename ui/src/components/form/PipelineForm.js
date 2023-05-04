import React, { useState, useRef, useEffect } from 'react';
import Select from 'react-select';
import InputFileInput from './InputFileInput';

const BonInABoxScriptService = require('bon_in_a_box_script_service');
export const api = new BonInABoxScriptService.DefaultApi();

export function PipelineForm({ pipelineMetadata, setPipelineMetadata, setRunId, showHttpError }) {
  const formRef = useRef();

  const defaultPipeline = "helloWorld.json";
  const [pipelineOptions, setPipelineOptions] = useState([]);

  /**
   * String: Content of input.json for this run
   */
  const [inputFileContent, setInputFileContent] = useState({});

  function clearPreviousRequest() {
    showHttpError(null);
    setRunId(null);
  }

  function loadPipelineMetadata(choice) {
    clearPreviousRequest();
    setPipelineMetadata(null);

    var callback = function (error, data, response) {
      if (error) {
        showHttpError(error, response);
      } else if (data) {
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
    var callback = function (error, data, response) {
      if (error) { // Server / connection errors. Data will be undefined.
        data = {};
        showHttpError(error, response);

      } else if (data) {
        setRunId(data);
      } else {
        showHttpError("Server returned empty result");
      }
    };

    clearPreviousRequest();
    let opts = {
      'body': JSON.stringify(inputFileContent)
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
    <form ref={formRef} onSubmit={handleSubmit} acceptCharset="utf-8">
      <label htmlFor='pipelineChoice'>Pipeline:</label>
      <Select id="pipelineChoice" name="pipelineChoice" className="blackText" options={pipelineOptions}
        defaultValue={{ label: defaultPipeline, value: defaultPipeline }}
        onChange={(v) => loadPipelineMetadata(v.value)} />
      <br />
      <InputFileInput
        metadata={pipelineMetadata}
        inputFileContent={inputFileContent}
        setInputFileContent={setInputFileContent} />
      <br />
      <input type="submit" disabled={false} value="Run pipeline" />
    </form>
  );
}
