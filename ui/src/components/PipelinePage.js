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
import { useNavigate, useParams, useLocation } from "react-router-dom";

const defaultPipeline = "helloWorld";

const BonInABoxScriptService = require("bon_in_a_box_script_service");
export const api = new BonInABoxScriptService.DefaultApi();

function pipReducer(state, action) {
  switch (action.type) {
    case "run": {
      return {
        lastAction: "run",
        runHash: action.newHash,
        pipeline: state.pipeline,
        runId: state.pipeline + ">" + action.newHash,
      };
    }
    case "select": {
      return {
        lastAction: "select",
        runHash: null,
        pipeline: action.newPipeline,
        runId: null,
      };
    }
    case "url": {
      return {
        lastAction: "url",
        runHash: action.newHash,
        pipeline: action.newPipeline,
        runId: action.newPipeline + ">" + action.newHash,
      };
    }
    case "reset": {
      return {
        lastAction: "reset",
        runHash: null,
        pipeline: defaultPipeline,
        runId: null,
      };
    }
  }
  throw Error("Unknown action: " + action.type);
}

function pipInitialState(pipelineRunId) {
  let runHash = null;
  let pipeline = defaultPipeline;
  let action = "reset";
  if (pipelineRunId) {
    const parts = pipelineRunId.split(">");
    runHash = parts.at(-1);
    pipeline = parts.at(-2);
    action = "url";
  }
  return {
    lastAction: action,
    runHash: runHash,
    pipeline: pipeline,
    runId: pipeline + ">" + runHash,
  };
}

export function PipelinePage() {
  const [stoppable, setStoppable] = useState(null);
  const [runningScripts, setRunningScripts] = useState(new Set());
  const [resultsData, setResultsData] = useState(null);
  const [httpError, setHttpError] = useState(null);
  const [pipelineMetadata, setPipelineMetadata] = useState(null);
  const [selectedPipeline, setSelectedPipeline] = useState("helloWorld.json");

  /**
   * String: Content of input.json for this run
   */
  const [inputFileContent, setInputFileContent] = useState({});

  const { pipelineRunId } = useParams();
  const [pipStates, setPipStates] = useReducer(
    pipReducer,
    pipelineRunId,
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
      api.getPipelineOutputs(pipStates.runId, (error, data, response) => {
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
    choice = choice + ".json";
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
    api.getPipelineInfo(choice, callback);
  }

  function loadInputJson(pip, hash) {
    var inputJson = "/output/" + pip + "/" + hash + "/input.json";
    fetch(inputJson)
      .then((response) => {
        if (response.ok) {
          return response.json();
        }
        if (response.status === 404) {
          // This is a new run
          setPipStates({
            type: "run",
            newPipeline: pip,
            newHash: hash,
          });
          return false;
        }
      })
      .then((json) => {
        if (json) {
          // This has been run before
          setPipStates({
            type: "url",
            newPipeline: pip,
            newHash: hash,
          });
          loadPipelineMetadata(pip, false);
          setInputFileContent(json);
        }
      });
  }

  useEffect(() => {
    setStoppable(runningScripts.size > 0);
  }, [runningScripts]);

  useEffect(() => {
    loadPipelineOutputs();
    if (["reset", "select"].includes(pipStates.lastAction)) {
      loadPipelineMetadata(pipStates.pipeline, true);
    }
    if (["run"].includes(pipStates.lastAction)) {
      loadPipelineMetadata(pipStates.pipeline, false);
    }
  }, [pipStates]);

  useEffect(() => {
    // set by the route
    if (pipelineRunId && pipelineRunId !== "null") {
      const runIdParts = pipelineRunId.split(">");
      var hash = runIdParts.at(-1);
      var pip = runIdParts.at(-2);
      loadInputJson(pip, hash);
    }
  }, [pipelineRunId]);

  const stop = () => {
    setStoppable(false);
    api.stopPipeline(pipStates.runId, (error, data, response) => {
      if (response.status === 200) {
        setHttpError("Cancelled by user");
      }
    });
  };

  return (
    <>
      <h2>Pipeline run</h2>
      <FoldableOutput
        title="Input form"
        isActive={!pipStates.runId}
        keepWhenHidden={true}
      >
        <PipelineForm
          pipelineMetadata={pipelineMetadata}
          setInputFileContent={setInputFileContent}
          inputFileContent={inputFileContent}
          setSelectedPipeline={setSelectedPipeline}
          selectedPipeline={selectedPipeline}
          pipStates={pipStates}
          setPipStates={setPipStates}
          showHttpError={showHttpError}
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
          pipelineRunId={pipelineRunId}
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
  pipelineRunId,
}) {
  const [activeRenderer, setActiveRenderer] = useState({});
  const [pipelineOutputResults, setPipelineOutputResults] = useState({});

  useEffect(() => {
    if (resultsData === null || pipelineRunId) {
      // Put outputResults at initial value
      const initialValue = {};
      if (pipelineMetadata.outputs) {
        Object.keys(pipelineMetadata.outputs).forEach((key) => {
          initialValue[getBreadcrumbs(key)] = {};
        });
      }
      setPipelineOutputResults(initialValue);
    }
  }, [pipelineMetadata.outputs, resultsData]);

  if (resultsData) {
    return (
      <RenderContext.Provider
        value={createContext(activeRenderer, setActiveRenderer)}
      >
        <h2>Pipeline</h2>
        {pipelineMetadata.outputs &&
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

    api.getScriptInfo(script, callback);
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
