import React, { useRef, useEffect } from 'react';

export function InputFileWithExample(props) {
  const textareaRef = useRef(null);

  /**
   * Automatic horizontal and vertical resizing of textarea
   * @param {textarea} input
   */
  function resize(input) {
    input.style.height = "auto";
    input.style.height = (input.scrollHeight) + "px";

    input.style.width = "auto";
    input.style.width = (input.scrollWidth) + "px";
  }

  useEffect(() => {
    // Generate example input.json
    let inputExamples = {};

    let meta = props.metadata;
    if (meta && meta.inputs) {
      Object.keys(meta.inputs).forEach((inputKey) => {
        let input = meta.inputs[inputKey];
        if (input) {
          const example = input.example;
          inputExamples[inputKey] = example ? example : "...";
        }
      });
    }

    textareaRef.current.value = JSON.stringify(inputExamples, null, 2);
    resize(textareaRef.current);
  }, [props.metadata]);

  return <textarea ref={textareaRef} name="inputFile" className="inputFile" type="text" defaultValue={props.defaultValue}
    onInput={(e) => resize(e.target)}></textarea>;
}
