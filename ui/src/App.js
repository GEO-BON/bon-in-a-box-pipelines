import { useState } from "react";
import spinner from './spinner.svg';
import './App.css';
const BonInABoxScriptService = require('bon_in_a_box_script_service');

const RequestState = Object.freeze({"idle":1, "working":2, "done":3, "error":4})

function App() {
  const [requestState, setRequestState] = useState(RequestState.idle);
  const [result, setResult] = useState(RequestState.idle);

  return (
    <>
      <header className="App-header">
        <h1>BON in a Box v2 pre-pre-pre alpha</h1>
      </header>
      <Form setRequestState={setRequestState} setResult={setResult} />
      <Result requestState={requestState} result={result} />
    </>
  );
}

function Form(props) {

  const queryInfo = () => {
    props.setRequestState(RequestState.working)

    var api = new BonInABoxScriptService.DefaultApi()
    var scriptPath = "HelloWorld.R"; // {String} Where to find the script in ./script folder
    var callback = function (error, data, response) {
      if (error) {
        props.setResult(data);
        props.setRequestState(RequestState.error)
        console.error(error);
        alert(error)

      } else {
        props.setResult(data);
        props.setRequestState(RequestState.done)
        console.log('API called successfully. Returned data: ' + data);
        alert('API called successfully. ' + response + ' Returned data: ' + data)
      }
    }

    props.setResult(null);
    api.getScriptInfo(scriptPath, callback);
  }


  const runScript = () => {
    props.setRequestState(RequestState.working)

    var api = new BonInABoxScriptService.DefaultApi()
    var scriptPath = "HelloWorld.R"; // {String} Where to find the script in ./script folder
    var callback = function (error, data, response) {
      if (error) {
        props.setResult(data);
        props.setRequestState(RequestState.error)
        alert(error)
        console.error(error);

      } else {
        props.setResult(data);
        props.setRequestState(RequestState.done)
        console.log('API called successfully. Returned data: ' + data);
      }
    };

    props.setResult(null);
    api.runScript(scriptPath, {"params":["test1", "test2"]}, callback);
  }

  return (
    <>
        <button onClick={runScript} disabled={props.requestState === RequestState.working}>Run script</button>
        <button onClick={queryInfo} disabled={props.requestState === RequestState.working}>Get script info</button>
    </>
  );
}

function Result(props) {
  if(props.requestState === RequestState.idle)
    return null

  if (props.requestState === RequestState.working) 
    return (
      <div>
        <img src={spinner} className="spinner" alt="Spinner" />
      </div>
    );

  return (
    <div>
      <RenderedFiles files={props.result.files} />
      <div className="logs">
        <h3>Logs</h3>
        <pre>{props.result.logs}</pre>
      </div>
    </div>
  )

}

function RenderedFiles(props) {
  if(props.files) {
    return Object.entries(props.files).map(entry => {
      const [key, value] = entry;
      console.log(key, value);
      return (
        <div>
          <h3>{key}</h3>
          <img src={value} alt={key} />
        </div>
      )
    });
  } else {
    return null
  }
}

export default App
