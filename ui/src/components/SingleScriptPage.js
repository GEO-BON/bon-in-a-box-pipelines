import React, { useState, useRef, useEffect } from 'react';
import Select from 'react-select';

import { Result } from "./Result";
import spinner from '../img/spinner.svg';
import { InputFileWithExample } from './InputFileWithExample';

const RequestState = Object.freeze({"idle":1, "working":2, "done":3})

const BonInABoxScriptService = require('bon_in_a_box_script_service');
const yaml = require('js-yaml');

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
      <Result data={resultData} metadata={scriptMetadata} />
    )}
  </>)
}

function SingleScriptForm(props) {
  const formRef = useRef(null);

  const defaultScript = "HelloWorld>HelloR.yml";
  const [scriptFileOptions, setScriptFileOptions] = useState([]);

  function loadScriptMetadata(choice) {
    // TODO: cancel previous pending request?
    props.setRequestState(RequestState.done);
    props.setResultData(null);

    var api = new BonInABoxScriptService.DefaultApi();
    var callback = function (error, data, response) {
      props.setScriptMetadata(yaml.load(data));
      props.setResultData({ httpError: error ? error.toString() : null, rawMetadata: data });
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

    var api = new BonInABoxScriptService.DefaultApi();
    var callback = function (error, data /*, response*/) {
      if (error) { // Server / connection errors. Data will be undefined.
        data = {};
        data.httpError = error.toString();

      } else if (data && data.error) { // Errors reported by server
        // Add a preamble if there was not a script-generated error on top
        if (!data.files)
          data.files = {};
        if (!data.files.error) {
          data.files.error = "An error occured. ";
        }
        data.files.error += "Please check logs for details.";
      }
      // For script-generated errors, nothing to do
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
      'body': formRef.current.elements["inputFile"].value // String | Content of input.json for this run
    };
    api.runScript(scriptPath, opts, callback);
  };

  // Applied only once when first loaded  
  useEffect(() => {
    // Load list of scripts into scriptFileOptions
    let api = new BonInABoxScriptService.DefaultApi();
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
        <InputFileWithExample defaultValue='{&#10;"occurence":"/output/result/from/previous/script",&#10;"intensity":3&#10;}'
          scriptMetadata={props.scriptMetadata} />
      </label>
      <br />
      <input type="submit" disabled={props.requestState === RequestState.working} value="Run script" />
    </form>
  );
}
