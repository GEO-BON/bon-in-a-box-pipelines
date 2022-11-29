import React, { useRef, useEffect } from 'react';

export function InputFileWithExample({defaultValue, metadata}) {
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

    if (metadata && metadata.inputs) {
      Object.keys(metadata.inputs).forEach((inputKey) => {
        let input = metadata.inputs[inputKey];
        if (input) {
          const example = input.example;
          inputExamples[inputKey] = example === undefined ? null : example;
        }
      });
    }

    textareaRef.current.value = JSON.stringify(inputExamples, null, 2);
    resize(textareaRef.current);
  }, [metadata]);

  return <textarea ref={textareaRef} name="inputFile" className="inputFile" type="text" defaultValue={defaultValue}
    onInput={(e) => resize(e.target)}></textarea>;
}
