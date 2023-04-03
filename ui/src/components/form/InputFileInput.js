import { useEffect } from "react";
import { AutoResizeTextArea } from "./AutoResizeTextArea";

/**
 * An input that we use to fill the input file's content. 
 * I agree, the name sounds weird. 
 */
export default function InputFileInput({ metadata, inputFileContent, setInputFileContent }) {
  // Everytime we choose a pipeline, generate example input.json
  useEffect(() => {
    let inputExamples = {};

    if (metadata && metadata.inputs) {
      Object.keys(metadata.inputs).forEach((inputKey) => {
        let input = metadata.inputs[inputKey];
        if (input) {
          const example = input.example;
          inputExamples[inputKey] = example === undefined ? null : example;
        }
      });
    }

    setInputFileContent(inputExamples)

  }, [metadata]);

  return <AutoResizeTextArea data={inputFileContent} setData={setInputFileContent} />
}