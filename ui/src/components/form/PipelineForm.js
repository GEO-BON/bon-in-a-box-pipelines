import React, { useState, useRef, useEffect } from "react";
import Select from "react-select";
import InputFileInput from "./InputFileInput";
import { useNavigate } from "react-router-dom";

const BonInABoxScriptService = require("bon_in_a_box_script_service");
export const api = new BonInABoxScriptService.DefaultApi();

export function PipelineForm({
  pipelineMetadata,
  pipStates,
  setPipStates,
  showHttpError,
  inputFileContent,
  setInputFileContent,
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
    runScript();
  };

  const handlePipelineChange = (value) => {
    clearPreviousRequest();
    setPipStates({
      type: "select",
      newPipeline: value,
    });
    navigate("/pipeline-form");
  };

  const runScript = () => {
    var callback = function (error, data, response) {
      if (error) {
        // Server / connection errors. Data will be undefined.
        data = {};
        showHttpError(error, response);
      } else if (data) {
        const parts = data.split(">");
        let runHash = parts.at(-1);
        let pipeline = parts.slice(0,-1).join(">")
        navigate("/pipeline-form/" + pipeline + "/" + runHash);
      } else {
        showHttpError("Server returned empty result");
      }
    };

    clearPreviousRequest();
    let opts = {
      body: JSON.stringify(inputFileContent),
    };
    api.runPipeline(pipStates.pipeline + ".json", opts, callback);
  };

  // Applied only once when first loaded
  useEffect(() => {
    // Load list of scripts into pipelineOptions
    api.pipelineListGet((error, data, response) => {
      if (error) {
        console.error(error);
      } else {
        let newOptions = [];
        data.forEach((script) => {
          script = script.replace(".json", "");
          newOptions.push({ label: script, value: script });
        });
        setPipelineOptions(newOptions);
      }
    });
    // Empty dependency array to get script list only once
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <form ref={formRef} onSubmit={handleSubmit} acceptCharset="utf-8">
      <label htmlFor="pipelineChoice">Pipeline:</label>
      <Select
        id="pipelineChoice"
        name="pipelineChoice"
        className="blackText"
        options={pipelineOptions}
        value={{
          label: pipStates.pipeline,
          value: pipStates.pipeline,
        }}
        menuPortalTarget={document.body}
        onChange={(v) => handlePipelineChange(v.value)}
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
