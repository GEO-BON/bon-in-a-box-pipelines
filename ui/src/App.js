import { useState } from "react";
import spinner from './spinner.svg';
import './App.css';
import RenderedMap from './RenderedMap'

import React, {useRef, useEffect} from 'react'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'

const BonInABoxScriptService = require('bon_in_a_box_script_service');
const RequestState = Object.freeze({"idle":1, "working":2, "done":3})

function App() {
  const [requestState, setRequestState] = useState(RequestState.idle);
  const [renderers, setRenderers] = useState([]);
  const [activeRenderer, setActiveRenderer] = useState([]);

  return (
    <>
      <header className="App-header">
        <h1>BON in a Box v2 pre-pre-pre alpha</h1>
      </header>
      <Form setRequestState={setRequestState} setRenderers={setRenderers} />
      <Result requestState={requestState} renderers={renderers} activeRenderer={activeRenderer} setActiveRenderer={setActiveRenderer} />
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
        error && new RenderedErrorFactory(error.toString()),
        data && new ReactMarkdownFactory(data)
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
        props.setRenderers([new RenderedErrorFactory(error.toString())]);
      }
      else if (data) {
        props.setRenderers([
          new RenderedFilesFactory(data.files),
          new RenderedLogsFactory(data.logs)
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
  function toggleVisibility(componentId) {
    props.setActiveRenderer(props.activeRenderer === componentId ? null : componentId)
  }

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
        {props.renderers.map(factory => {
            return factory == null ? null : factory.createComponent(props.activeRenderer, toggleVisibility)
        })}
      </div>
    )
  }

  return null
}

function isRelativeLink(value)
{
  return value.startsWith('/')
}

function OutputTitle (props) {
  let active = props.activeRenderer === props.componentId
  const titleRef = useRef(null);

  useEffect(() => {
    if(active) {
      titleRef.current.scrollIntoView({ block: 'start',  behavior: 'smooth' })
    }
  }, [active]);

  return <div className="outputTitle">
    <h3 ref={titleRef}  onClick={() => props.toggleVisibility(props.componentId)}>
      {active ? <b>–</b> : <b>+</b>} {props.title}
    </h3>
    {props.inline && (
      isRelativeLink(props.inline) ? (
        active && props.inline && <a href={props.inline} target="_blank" rel="noreferrer">{props.inline}</a>
      ) : (
        !active && props.inline
      )
    )}
  </div>
}

class ReactMarkdownFactory {
  constructor(markdown) {
    this.markdown = markdown
  }

  createComponent(/*activeRenderer, toggleVisibility*/) {
      return <ReactMarkdown key="info" remarkPlugins={[remarkGfm]}>{this.markdown}</ReactMarkdown>
  }
}

class RenderedFilesFactory {
  constructor(files) {
    this.files = files
  }

  createComponent(activeRenderer, toggleVisibility) {
      return <RenderedFiles key="files" files={this.files} activeRenderer={activeRenderer} toggleVisibility={toggleVisibility} />
  }
}

function RenderedFiles(props) {
  if(props.files) {
    return Object.entries(props.files).map(entry => {
      const [key, value] = entry;

      return (
        <div key={key}>
          <OutputTitle title={key} componentId={key} inline={value} activeRenderer={props.activeRenderer} toggleVisibility={props.toggleVisibility} />
          {props.activeRenderer === key && (
            isRelativeLink(value) ? (
            // Match for tiff, TIFF, tif or TIF extensions
            value.search(/.tiff?$/i) !== -1 ? (
              <RenderedMap tiff={value} />
            ) : (
              <img src={value} alt={key} />
              )
            ) : ( // Plain text or numeric value
              <p>{value}</p>
            )
          )}
        </div>
      )

    });
  } else {
    return null
  }
}

class RenderedLogsFactory {
  constructor(logs) {
    this.logs = logs
  }

  createComponent(activeRenderer, toggleVisibility) {
      return <RenderedLogs key="logs" logs={this.logs} activeRenderer={activeRenderer} toggleVisibility={toggleVisibility} />
  }
}

function RenderedLogs(props) {
  let myId="logs"

  if (props.logs) {
    return (<div className="logs">
      <OutputTitle title="Logs" componentId={myId} activeRenderer={props.activeRenderer} toggleVisibility={props.toggleVisibility} />
      {props.activeRenderer === myId && <pre>{props.logs}</pre>}
    </div>)
  }
  return null
}

class RenderedErrorFactory {
  constructor(error) {
    this.error = error
  }

  createComponent(/*toggleVisibility always visible*/) {
      return <RenderedError key="error" error={this.error}  />
  }
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
