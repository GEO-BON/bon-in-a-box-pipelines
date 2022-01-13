import { useState } from "react";
import spinner from './spinner.svg';
import './App.css';
import RenderedMap from './RenderedMap'

import React, {useRef} from 'react'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'

import uuid from 'react-uuid'

const BonInABoxScriptService = require('bon_in_a_box_script_service');
const RequestState = Object.freeze({"idle":1, "working":2, "done":3})

function App() {
  const [requestState, setRequestState] = useState(RequestState.idle);
  const [renderers, setRenderers] = useState([]);

  return (
    <>
      <header className="App-header">
        <h1>BON in a Box v2 pre-pre-pre alpha</h1>
      </header>
      <Form setRequestState={setRequestState} setRenderers={setRenderers} />
      <Result requestState={requestState} renderers={renderers} />
    </>
  );
}

function Form(props) {
  // Where to find the script in ./script folder
  const inputScriptRef = useRef(null);
  // Parameters of the script. In the URL as ...?params=param1,param2
  const paramRef = useRef(null);

  const queryInfo = () => {
    props.setRequestState(RequestState.working)
    props.setRenderers(null);

    var api = new BonInABoxScriptService.DefaultApi()
    var callback = function (error, data, response) {
      props.setRenderers([
        error && <RenderedError error={error.toString()} />,
        data && <ReactMarkdown remarkPlugins={[remarkGfm]}>{data}</ReactMarkdown>
      ])

      props.setRequestState(RequestState.done)
    }

    api.getScriptInfo(inputScriptRef.current.value, callback);
  }

  const handleSubmit = (event) => {
    event.preventDefault();

    runScript()
  }

  const runScript = () => {
    props.setRequestState(RequestState.working)

    var api = new BonInABoxScriptService.DefaultApi()
    var callback = function (error, data, response) {
      if(error)
      {
        props.setRenderers([(<RenderedError error={error.toString()} />)]);
      }
      else if (data) {
        props.setRenderers([
          (<RenderedFiles files={data.files} />),
          (<RenderedLogs logs={data.logs} />)
        ])
      }

      props.setRequestState(RequestState.done)
    };

    props.setRenderers(null); // make sure we don't mix with last request

    let paramsValue = paramRef.current.value
    let params = paramsValue ? {"params":paramsValue.split('\n')} : {}

    api.runScript(inputScriptRef.current.value, params, callback);
  }

  return (
    <form onSubmit={handleSubmit}>
      <label>
        Script file :
        <br />
        <input ref={inputScriptRef} type="text" defaultValue="HelloWorld.R" />
      </label>
      <button type="button" onClick={queryInfo} disabled={props.requestState === RequestState.working}>Get script info</button>
      <br /> {/*Why do I need to line break, forms should do it normally... */}
      <label>
        Parameters (1 per line) :
        <br />
        <textarea ref={paramRef} type="text" defaultValue="param1&#10;param2"></textarea>
      </label>
      <br />
      <input type="submit" disabled={props.requestState === RequestState.working} value="Run script" />
    </form>
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

  if(props.renderers && props.renderers.length > 0)
  {
    return (
      <div>
        {props.renderers}
      </div>
    )
  }

  return null
}

function RenderedFiles(props) {
  if(props.files) {
    return Object.entries(props.files).map(entry => {
      const [key, value] = entry;

      // Match for tiff, TIFF, tif or TIF extensions
      if (value.search(/.tiff?$/i) !== -1) {
        return <RenderedMap key={key} title={key} tiff={value} />
      }
      else {
        return (
          <div key={key}>
            <h3>{key}</h3>
            <img src={value} alt={key} />
          </div>
        )
      }
    });
  } else {
    return null
  }
}

function RenderedLogs(props) {
  if (props.logs) {
    return (<div key={myId} className="logs">
      <h3>Logs</h3>
      <pre>{props.logs}</pre>
    </div>)
  }
  return null
}

function RenderedError(props) {
  if (props.error) {
    return (<div className="error">
      <p>{props.error}</p>
    </div>)
  }
  return null
}

export default App
