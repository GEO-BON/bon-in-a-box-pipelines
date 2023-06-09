import React, { useState, useRef, useEffect } from 'react';
import Select from 'react-select';

import { StepResult } from "./StepResult";
import spinner from '../img/spinner.svg';
import { GeneralDescription } from './ScriptDescription';
import InputFileInput from './form/InputFileInput';

const RequestState = Object.freeze({"idle":1, "working":2, "done":3})

const BonInABoxScriptService = require('bon_in_a_box_script_service');

export function SingleScriptPage(props) {
  const [requestState, setRequestState] = useState(RequestState.idle);
  const [resultData, setResultData] = useState();
  const [scriptMetadata, setScriptMetadata] = useState({});

 return (
  <>
    <h2>Single script run</h2>
    <SingleScriptForm setResultData={setResultData} setRequestState={setRequestState}
      scriptMetadata={scriptMetadata} setScriptMetadata={setScriptMetadata} />
    
    {requestState !== RequestState.idle && requestState === RequestState.working ? (
      <div>
        <img src={spinner} className="spinner" alt="Spinner" />
      </div>
    ) : (
      <>
        {resultData && resultData.httpError && <p key="httpError" className="error">{resultData.httpError}</p>}
        {resultData && <StepResult data={resultData.files} logs={resultData.logs} metadata={scriptMetadata} />}
      </>
    )}
  </>)
}

function SingleScriptForm(props) {
  const formRef = useRef();
  const api = new BonInABoxScriptService.DefaultApi();

  const defaultScript = "helloWorld>helloR.yml";
  const [scriptFileOptions, setScriptFileOptions] = useState([]);

  /**
   * String: Content of input.json for this run
   */
  const [inputFileContent, setInputFileContent] = useState({});

  function loadScriptMetadata(choice) {
    // TODO: cancel previous pending request?
    props.setRequestState(RequestState.idle);
    setInputFileContent({})
    props.setResultData(null);

    var callback = function (error, data, response) {
      props.setScriptMetadata(data);
      props.setResultData({ httpError: error ? error.toString() : null });
    };

    api.getScriptInfo(choice, callback);
  }

  const handleSubmit = (event) => {
    event.preventDefault();

    runScript();
  };

  const runScript = () => {
    props.setRequestState(RequestState.working);
    props.setResultData(null);

    var callback = function (error, data /*, response*/) {
      if (error) { // Server / connection errors. Data will be undefined.
        data = {};
        data.httpError = error.toString();
      }

      props.setResultData(data);
      props.setRequestState(RequestState.done);
    };

    // Script path: folder from yml + script name
    let scriptPath = props.scriptMetadata.script;
    let ymlPath = formRef.current.elements["scriptFile"].value;
    if (ymlPath.includes('>')) {
      scriptPath = ymlPath.replace(new RegExp(">[^>]+$"), `>${scriptPath}`);
    }

    let opts = {
      'body': JSON.stringify(inputFileContent)
    };
    api.runScript(scriptPath, opts, callback);
  };

  // Applied only once when first loaded  
  useEffect(() => {
    // Load list of scripts into scriptFileOptions
    api.scriptListGet((error, data, response) => {
      if (error) {
        console.error(error);
      } else {
        let newOptions = [];
        data.forEach(script => newOptions.push({ label: script, value: script }));
        setScriptFileOptions(newOptions);
        loadScriptMetadata(defaultScript);
      }
    });
    // Empty dependency array to get script list only once
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <form ref={formRef} onSubmit={handleSubmit} acceptCharset="utf-8">
      <label htmlFor='scriptFile'>Script file:</label>
      <Select id="scriptFile" name="scriptFile" className="blackText" options={scriptFileOptions}
        defaultValue={{ label: defaultScript, value: defaultScript }}
        menuPortalTarget={document.body}
        onChange={(v) => loadScriptMetadata(v.value)} />
      <br />
      {props.scriptMetadata &&
        <pre key="metadata">
          <GeneralDescription ymlPath={null} metadata={props.scriptMetadata} />
        </pre>
      }
      <br />
      <InputFileInput metadata={props.scriptMetadata}
        inputFileContent={inputFileContent}
        setInputFileContent={setInputFileContent} />
      <br />
      <input type="submit" disabled={props.requestState === RequestState.working} value="Run script" />
    </form>
  );
}
