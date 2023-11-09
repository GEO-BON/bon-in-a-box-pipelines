import YAMLTextArea from "./YAMLTextArea";
import { InputsDescription } from "../StepDescription";
import { Tabs, Tab, TabList, TabPanel } from "react-tabs";

import "react-tabs/style/react-tabs.css";
import "./react-tabs-dark.css";
import "./InputFileInputs.css";
import ScriptInput from "./ScriptInput";

const yaml = require("js-yaml");

/**
 * An input that we use to fill the input file's content.
 * I agree, the name sounds weird.
 */
export default function InputFileInput({
  metadata,
  inputFileContent,
  setInputFileContent,
}) {
  return (
    <>
      <Tabs>
        <TabList>
          <Tab>Input form</Tab>
          <Tab>Input yaml</Tab>
        </TabList>

        <TabPanel>
          {metadata && (
            <InputForm
              inputs={metadata.inputs}
              inputFileContent={inputFileContent}
              setInputFileContent={setInputFileContent}
            />
          )}
        </TabPanel>
        <TabPanel>
          <YAMLTextArea data={inputFileContent} setData={setInputFileContent} />
          <InputsDescription metadata={metadata} />
        </TabPanel>
      </Tabs>
    </>
  );
}

const InputForm = ({ inputs, inputFileContent, setInputFileContent }) => {
  if (!inputs) return <p>No Inputs</p>;

  function updateInputFile(inputId, value) {
    setInputFileContent((content) => {
      const newContent = { ...content };
      newContent[inputId] = value;
      return newContent;
    });
  }

  return (
    <table className="inputFileFields">
      <tbody>
        {Object.entries(inputs).map(([inputId, inputDescription]) => {
          const { label, description, options, example, ...theRest } = inputDescription;

          return (
            <tr key={inputId}>
              <td className="inputCell">
                <label htmlFor={inputId}>
                  <strong>{label}</strong>
                </label>
                <ScriptInput
                  id={inputId}
                  type={inputDescription.type}
                  options={options}
                  value={inputFileContent && inputFileContent[inputId]}
                  onValueUpdated={(value) => updateInputFile(inputId, value)}
                  cols="50"
                />
              </td>
              <td className="descriptionCell">
                {description + "\n" + yaml.dump(theRest)}
                {example && <>
                  Example:<br />
                  <ScriptInput
                    id={inputId}
                    type={inputDescription.type}
                    options={options}
                    value={example}
                    disabled={true}
                    cols="50"
                    className="example"
                  />
                </>}
              </td>
            </tr>
          );
        })}
      </tbody>
    </table>
  );
};
