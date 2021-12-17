import { useState } from "react";
import spinner from './spinner.svg';
import './App.css';
const BonInABoxScriptService = require('bon_in_a_box_script_service');

const RequestState = Object.freeze({"idle":1, "working":2, "done":3, "error":4})

function App() {
  const [requestState, setRequestState] = useState(RequestState.idle);
  return (
    <>
      <header className="App-header">
        <h1>BON in a Box v2 pre-pre-pre alpha</h1>
      </header>
      <Form requestState={requestState} setRequestState={setRequestState} />
      <Result requestState={requestState} />
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
        props.setRequestState(RequestState.error)
        console.error(error);
        alert(error)

      } else {
        props.setRequestState(RequestState.done)
        console.log('API called successfully. Returned data: ' + data);
        alert('API called successfully. ' + response + ' Returned data: ' + data)
      }
    }
    api.getScriptInfo(scriptPath, callback);
  }


  const runScript = () => {
    props.setRequestState(RequestState.working)

    var api = new BonInABoxScriptService.DefaultApi()
    var scriptPath = "HelloWorld.R"; // {String} Where to find the script in ./script folder
    var callback = function (error, data, response) {
      console.log('Got callback');
      if (error) {
        props.setRequestState(RequestState.error)
        alert(error)
        console.error(error);

      } else {
        props.setRequestState(RequestState.done)
        console.log('API called successfully. Returned data: ' + data);
        alert('API called successfully. ' + response + ' Returned data: ' + data)
      }
    };

    console.log('Launching');
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
  if (props.requestState === RequestState.working) {
    return (
      <div>
        <img src={spinner} className="spinner" alt="Spinner" />
      </div>
    );
  }

  return null;
}

export default App
