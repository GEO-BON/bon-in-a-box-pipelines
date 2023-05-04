import { useEffect } from "react";
import { AutoResizeTextArea } from "./AutoResizeTextArea";
import { InputsDescription } from "../ScriptDescription";
import { Tabs, Tab, TabList, TabPanel } from "react-tabs"

import 'react-tabs/style/react-tabs.css';
import './react-tabs-dark.css'
import './InputFileInputs.css'
import ScriptInput from "./ScriptInput";

const yaml = require('js-yaml');

/**
 * An input that we use to fill the input file's content. 
 * I agree, the name sounds weird. 
 */
export default function InputFileInput({ metadata, inputFileContent, setInputFileContent }) {

  // Everytime we choose a pipeline, generate example input.json
  useEffect(() => {
    let inputExamples = {};

    if (metadata && metadata.inputs) {
      Object.keys(metadata.inputs).forEach((inputId) => {
        let input = metadata.inputs[inputId];
        if (input) {
          const example = input.example;
          inputExamples[inputId] = example === undefined ? null : example;
        }
      });
    }

    setInputFileContent(inputExamples)

  }, [metadata, setInputFileContent]);

  return <>
    <Tabs>
      <TabList>
        <Tab>Input form</Tab>
        <Tab>Input yaml</Tab>
      </TabList>

      <TabPanel>
        {metadata && <InputForm inputs={metadata.inputs} inputFileContent={inputFileContent} setInputFileContent={setInputFileContent} />}
      </TabPanel>
      <TabPanel>
        <AutoResizeTextArea data={inputFileContent} setData={setInputFileContent} />
        <InputsDescription metadata={metadata} />
      </TabPanel>
    </Tabs>
  </>
}

const InputForm = ({inputs, inputFileContent, setInputFileContent}) => {
  if(!inputs)
    return <p>No Inputs</p>

  function updateInputFile(inputId, value) {
    setInputFileContent(content => {
      content[inputId] = value
      return content
    })
  }

  return <table className="inputFileFields" >
    {Object.entries(inputs).map(([inputId, inputDescription]) => {
      const { label, description, options, ...theRest } = inputDescription

      return <tr key={inputId}>
        <td className="inputCell">
          <label htmlFor={inputId}><strong>{label}</strong></label>
          <ScriptInput id={inputId} type={inputDescription.type} options={options} value={inputFileContent && inputFileContent[inputId]}
            onValueUpdated={value => updateInputFile(inputId, value)} />
        </td>
        <td className="descriptionCell">
          {description + '\n' + yaml.dump(theRest)}
        </td>
      </tr>
    })}
  </table>
    
}