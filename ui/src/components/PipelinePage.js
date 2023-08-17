import React, { useState, useEffect, useReducer } from "react";
import { SingleOutputResult, StepResult } from "./StepResult";
import {
  FoldableOutputWithContext,
  RenderContext,
  createContext,
  FoldableOutput,
} from "./FoldableOutput";

import { useInterval } from "../UseInterval";

import spinnerImg from "../img/spinner.svg";
import errorImg from "../img/error.svg";
import warningImg from "../img/warning.svg";
import infoImg from "../img/info.svg";
import { LogViewer } from "./LogViewer";
import { GeneralDescription } from "./ScriptDescription";
import { PipelineForm } from "./form/PipelineForm";
import {
  getScript,
  getScriptOutput,
  toDisplayString,
  getBreadcrumbs,
} from "../utils/IOId";
import { useParams } from "react-router-dom";
import { isEmptyObject } from "../utils/isEmptyObject";

const defaultPipeline = {name: "helloWorld", file: "helloWorld.json"};
const defaultScript = {name: "helloWorld > helloR", file: "helloWorld>helloR.yml"};

const BonInABoxScriptService = require("bon_in_a_box_script_service");
export const api = new BonInABoxScriptService.DefaultApi();

function pipReducer(state, action) {
  switch (action.type) {
    case "rerun": {
      return {
        ...state,
        lastAction: "rerun",
      };
    }
    case "select": {
      return {
        lastAction: "select",
        pipeline: action.newPipeline,
        descriptionFile: action.newDescriptionFile,
        runHash: null,
        runId: null,

        runType: state.runType,
      };
    }
    case "url": {
      return {
        lastAction: "url",
        runHash: action.newHash,
        pipeline: action.newPipeline,
        descriptionFile: action.newDescriptionFile,
        runId: action.newPipeline + ">" + action.newHash,

        runType: state.runType,
      };
    }
    case "reset": {
      return pipInitialState({ runType: action.runType })
    }
    default:
      throw Error("Unknown action: " + action.type);
  }
}

function pipInitialState(init) {
  let defaultSelection = init.runType === "pipeline" ? defaultPipeline : defaultScript
  let pip = defaultSelection.name
  let descriptionFile = defaultSelection.file

  let hash = null;
  let action = "reset";
  if (init.pipeline && init.runHash) {
    hash = init.runHash;
    pip = init.pipeline;
    action = "url";
  }

  return {
    lastAction: action,
    runHash: hash,
    pipeline: pip,
    descriptionFile: descriptionFile,
    runId: pip + ">" + hash,
    runType: init.runType,
  };
}

export function PipelinePage({runType}) {
  const [stoppable, setStoppable] = useState(null);
  const [runningScripts, setRunningScripts] = useState(new Set());
  const [resultsData, setResultsData] = useState(null);
  const [httpError, setHttpError] = useState(null);
  const [pipelineMetadata, setPipelineMetadata] = useState(null);

  /**
   * String: Content of input.json for this run
   */
  const [inputFileContent, setInputFileContent] = useState({});

  const { pipeline, runHash } = useParams();
  const [pipStates, setPipStates] = useReducer(
    pipReducer,
    {runType, pipeline, runHash},
    pipInitialState
  );

  function showHttpError(error, response) {
    if (response && response.text) setHttpError(response.text);
    else if (error) setHttpError(error.toString());
    else setHttpError(null);
  }

  let timeout;
  function loadPipelineOutputs() {
    if (pipStates.runHash) {
      api.getOutputFolders(runType, pipStates.runId, (error, data, response) => {
        if (error) {
          showHttpError(error, response);
        } else {
          let allOutputFoldersKnown = Object.values(data).every(
            (val) => val !== ""
          );
          if (!allOutputFoldersKnown) {
            // try again later
            timeout = setTimeout(loadPipelineOutputs, 1000);
          }
          setResultsData(data);
        }
      });
    } else {
      setResultsData(null);
    }
  }

  function loadPipelineMetadata(choice, setExamples = true) {
    var callback = function (error, data, response) {
      if (error) {
        showHttpError(error, response);
      } else if (data) {
        setPipelineMetadata(data);
        if (setExamples) {
          let inputExamples = {};
          if (data && data.inputs) {
            Object.keys(data.inputs).forEach((inputId) => {
              let input = data.inputs[inputId];
              if (input) {
                const example = input.example;
                inputExamples[inputId] = example === undefined ? null : example;
              }
            });
          }
          setInputFileContent(inputExamples);
        }
      }
    };
    api.getInfo(runType, choice, callback);
  }

  function loadInputJson(pip, descriptionFile, hash) {
    var inputJson = "/output/" + pip.replaceAll('>','/') + "/" + hash + "/input.json";
    fetch(inputJson)
      .then((response) => {
        if (response.ok) {
          return response.json();
        }

        // This has never ran. No inputs to load.
          return false;
      })
      .then((json) => {
        if (json) {
          // This has been run before, load the inputs
          setInputFileContent(json);
        }
      });
  }

  useEffect(() => {
    setStoppable(runningScripts.size > 0);
  }, [runningScripts]);

  useEffect(() => {
    setResultsData(null);

    switch(pipStates.lastAction) {
      case "reset":
      case "select":
        loadPipelineMetadata(pipStates.descriptionFile, true);
        break;
      case "rerun":
        break;
      case "url":
        loadPipelineMetadata(pipStates.descriptionFile, false);
        break;
      default:
        throw Error("Unknown action: " + pipStates.lastAction);
    }

    loadPipelineOutputs();
  }, [pipStates]);

  useEffect(() => {
    // set by the route
    if (pipeline && runHash) {
      let descriptionFile = pipeline + (runType === "pipeline" ? ".json" : ".yml")
      setPipStates({
        type: "url",
        newPipeline: pipeline,
        newDescriptionFile: descriptionFile,
        newHash: runHash,
      });

      loadInputJson(pipeline, descriptionFile, runHash);
    } else {
      setPipStates({
        type: "reset",
        runType: runType,
      });
    }
  }, [pipeline, runHash, runType]);

  const stop = () => {
    setStoppable(false);
    api.stop(runType, pipStates.runId, (error, data, response) => {
      if (response.status === 200) {
        setHttpError("Cancelled by user");
      }
    });
  };

  return (
    <>
      <h2>{runType === "pipeline" ? "Pipeline" : "Script"} run</h2>
      <FoldableOutput
        title="Input form"
        isActive={!pipStates.runHash}
        keepWhenHidden={true}
      >
        <PipelineForm
          pipelineMetadata={pipelineMetadata}
          setInputFileContent={setInputFileContent}
          inputFileContent={inputFileContent}
          pipStates={pipStates}
          setPipStates={setPipStates}
          showHttpError={showHttpError}
          setResultsData={setResultsData}
          runType={runType}
        />
      </FoldableOutput>

      {pipStates.runId && (
        <button onClick={stop} disabled={!stoppable}>
          Stop
        </button>
      )}
      {httpError && (
        <p key="httpError" className="error">
          {httpError}
        </p>
      )}
      {pipelineMetadata && (
        <PipelineResults
          key="results"
          pipelineMetadata={pipelineMetadata}
          resultsData={resultsData}
          runningScripts={runningScripts}
          setRunningScripts={setRunningScripts}
          runHash={runHash}
          isPipeline={runType === "pipeline"}
        />
      )}
    </>
  );
}

function PipelineResults({
  pipelineMetadata,
  resultsData,
  runningScripts,
  setRunningScripts,
  runHash,
  isPipeline,
}) {
  const [activeRenderer, setActiveRenderer] = useState({});
  const [pipelineOutputResults, setPipelineOutputResults] = useState({});

  useEffect(() => {
    if(!isEmptyObject(resultsData)) {
      setActiveRenderer(Object.keys(resultsData)[0])
    }
  }, [resultsData, setActiveRenderer])

  useEffect(() => {
    // Put outputResults at initial value
    const initialValue = {};
    if (pipelineMetadata.outputs) {
      Object.keys(pipelineMetadata.outputs).forEach((key) => {
        initialValue[getBreadcrumbs(key)] = {};
      });
    }
    setPipelineOutputResults(initialValue);
  }, [runHash]);

  if (resultsData) {
    return (
      <RenderContext.Provider
        value={createContext(activeRenderer, setActiveRenderer)}
      >
        <h2>Results</h2>
        {isPipeline && <>
          {pipelineOutputResults && pipelineMetadata.outputs &&
            Object.entries(pipelineMetadata.outputs).map((entry) => {
              const [ioId, outputDescription] = entry;
              const breadcrumbs = getBreadcrumbs(ioId);
              const outputId = getScriptOutput(ioId);
              const value =
                pipelineOutputResults[breadcrumbs] &&
                pipelineOutputResults[breadcrumbs][outputId];
              if (!value) {
                return (
                  <div key={ioId} className="outputTitle">
                    <h3>{outputDescription.label}</h3>
                    {runningScripts.size > 0 ? (
                      <img
                        src={spinnerImg}
                        alt="Spinner"
                        className="spinner-inline"
                      />
                    ) : (
                      <>
                        <img
                          src={warningImg}
                          alt="Warning"
                          className="error-inline"
                        />
                        See detailed results
                      </>
                    )}
                  </div>
                );
              }

              return (
                <SingleOutputResult
                  key={ioId}
                  outputId={outputId}
                  componentId={ioId}
                  outputValue={value}
                  outputMetadata={outputDescription}
                />
              );
            })}

          <h2>Detailed results</h2>
        </>
        }
        {Object.entries(resultsData).map((entry) => {
          const [key, value] = entry;

          return (
            <DelayedResult
              key={key}
              breadcrumbs={key}
              folder={value}
              setRunningScripts={setRunningScripts}
              setPipelineOutputResults={setPipelineOutputResults}
            />
          );
        })}
      </RenderContext.Provider>
    );
  } else return null;
}

function DelayedResult({
  breadcrumbs,
  folder,
  setRunningScripts,
  setPipelineOutputResults,
}) {
  const [resultData, setResultData] = useState(null);
  const [scriptMetadata, setScriptMetadata] = useState(null);
  const [running, setRunning] = useState(false);
  const [skippedMessage, setSkippedMessage] = useState();

  const script = getScript(breadcrumbs);

  useEffect(() => {
    // A script is running when we know it's folder but have yet no result nor error message
    let nowRunning = folder && !resultData;
    setRunning(nowRunning);

    setRunningScripts((oldSet) => {
      let newSet = new Set(oldSet);
      nowRunning ? newSet.add(folder) : newSet.delete(folder);
      return newSet;
    });
  }, [setRunningScripts, folder, resultData]);

  useEffect(() => {
    if (folder) {
      if (folder === "skipped") {
        setResultData({
          info: "Skipped: not necessary with the given parameters",
        });
        setSkippedMessage("Skipped");
      } else if (folder === "aborted") {
        setResultData({ warning: "Skipped due to previous failure" });
        setSkippedMessage("Aborted");
      } else if (folder === "cancelled") {
        setResultData({ warning: "Skipped when pipeline stopped" });
        setSkippedMessage("Cancelled");
      }
    }
    // Execute only when folder changes (omitting resultData on purpose)
  }, [folder]);

  const interval = useInterval(
    () => {
      // Fetch the output
      fetch("/output/" + folder + "/output.json")
        .then((response) => {
          if (response.ok) {
            clearInterval(interval);
            return response.json();
          }

          // Script not done yet: wait for next attempt
          if (response.status === 404) {
            return Promise.resolve(null);
          }

          return Promise.reject(response);
        })
        .then((json) => {
          // Detailed results
          setResultData(json);

          // Contribute to pipeline outputs (if this script is relevant)
          setPipelineOutputResults((results) => {
            if (breadcrumbs in results) results[breadcrumbs] = json;

            return results;
          });
        })
        .catch((response) => {
          clearInterval(interval);
          setResultData({
            error: response.status + " (" + response.statusText + ")",
          });
        });

      // Will start when folder has value, and continue the until resultData also has a value
    },
    running ? 1000 : null
  );

  useEffect(() => {
    // Script metadata
    var callback = function (error, data, response) {
      setScriptMetadata(data);
    };

    api.getInfo("script", script, callback);
  }, [script]);

  let content,
    inline = null;
  let className = "foldableScriptResult";
  if (folder) {
    if (resultData) {
      content = <StepResult data={resultData} metadata={scriptMetadata} />;
      inline = (
        <>
          {resultData.error && (
            <img src={errorImg} alt="Error" className="error-inline" />
          )}
          {resultData.warning && (
            <img src={warningImg} alt="Warning" className="error-inline" />
          )}
          {resultData.info && (
            <img src={infoImg} alt="Info" className="info-inline" />
          )}
          {skippedMessage && <i>{skippedMessage}</i>}
        </>
      );
    } else {
      content = <p>Running...</p>;
      inline = (
        <img src={spinnerImg} alt="Spinner" className="spinner-inline" />
      );
    }
  } else {
    content = <p>Waiting for previous steps to complete.</p>;
    className += " gray";
  }

  let logsAddress = folder && "/output/" + folder + "/logs.txt";

  return (
    <FoldableOutputWithContext
      title={toDisplayString(breadcrumbs)}
      componentId={breadcrumbs}
      inline={inline}
      className={className}
    >
      <GeneralDescription ymlPath={script} metadata={scriptMetadata} />
      {content}
      {folder && !skippedMessage && (
        <LogViewer address={logsAddress} autoUpdate={!resultData} />
      )}
    </FoldableOutputWithContext>
  );
}
