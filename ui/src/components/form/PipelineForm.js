import React, { useState, useRef, useEffect } from "react";
import Select from "react-select";
import InputFileInput from "./InputFileInput";
import { useNavigate } from "react-router-dom";
import { getFolderAndName } from "../ScriptDescription";

const BonInABoxScriptService = require("bon_in_a_box_script_service");
export const api = new BonInABoxScriptService.DefaultApi();

export function PipelineForm({
  pipelineMetadata,
  pipStates,
  setPipStates,
  showHttpError,
  inputFileContent,
  setInputFileContent,
  runType
}) {
  const formRef = useRef();
  const navigate = useNavigate();
  const [pipelineOptions, setPipelineOptions] = useState([]);

  function clearPreviousRequest() {
    showHttpError(null);
    setInputFileContent({});
  }

  const handleSubmit = (event) => {
    event.preventDefault();
    runPipeline();
  };

  const handlePipelineChange = (label, value) => {
    clearPreviousRequest();
    let pipelineForUrl = value.replace(/.json$/i, "").replace(/.yml$/i, "")
    navigate("/" + runType + "-form/" + pipelineForUrl);
  };

  const runPipeline = () => {
    var callback = function (error, runId, response) {
      if (error) {
        // Server / connection errors. Data will be undefined.
        showHttpError(error, response);
      } else if (runId) {
        const parts = runId.split(">");
        let runHash = parts.at(-1);
        let pipelineForUrl = parts.slice(0,-1).join(">")
        if(pipStates.runHash === runHash) {
          setPipStates({type: "rerun"});
        }

        navigate("/" + runType + "-form/" + pipelineForUrl + "/" + runHash);
      } else {
        showHttpError("Server returned empty result");
      }
    };

    let opts = {
      body: JSON.stringify(inputFileContent),
    };
    api.run(runType, pipStates.descriptionFile, opts, callback);
  };

  // Applied only once when first loaded
  useEffect(() => {
    // Load list of scripts/pipelines into pipelineOptions
    api.getListOf(runType, (error, data, response) => {
      if (error) {
        console.error(error);
      } else {
        let newOptions = [];
        Object.entries(data).forEach(([descriptionFile, pipelineName]) => {
          newOptions.push({
            label: getFolderAndName(descriptionFile, pipelineName),
            value: descriptionFile
          });
        });
        setPipelineOptions(newOptions);
      }
    });
  }, [runType, setPipelineOptions]);

  return (
    <form ref={formRef} onSubmit={handleSubmit} acceptCharset="utf-8">
      <label htmlFor="pipelineChoice">{runType === "pipeline" ? "Pipeline:" : "Script:"}</label>
      <Select
        id="pipelineChoice"
        name="pipelineChoice"
        className="blackText"
        options={pipelineOptions}
        value={{
          label: pipStates.pipeline,
          value: pipStates.descriptionFile,
        }}
        menuPortalTarget={document.body}
        onChange={(v) => handlePipelineChange(v.label, v.value)}
      />
      <br />
      <InputFileInput
        metadata={pipelineMetadata}
        inputFileContent={inputFileContent}
        setInputFileContent={setInputFileContent}
      />
      <br />
      <input type="submit" disabled={false} value="Run pipeline" />
    </form>
  );
}
