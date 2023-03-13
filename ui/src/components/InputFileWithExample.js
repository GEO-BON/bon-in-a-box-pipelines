import React, { useRef, useEffect, forwardRef, useImperativeHandle } from 'react';

const yaml = require('js-yaml');

export const InputFileWithExample = forwardRef(({metadata}, ref) => {
  const textareaRef = useRef(null);

  useImperativeHandle(ref, () => ({
    getValue() {
      if (textareaRef.current.value === '')
        return '{}'
      else
        return JSON.stringify(yaml.load(textareaRef.current.value))
    },
  }));

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

    const textarea = textareaRef.current;
    if(isEmptyObject(inputExamples)) {
      textarea.disabled = true
      textarea.placeholder = "No inputs"
      textarea.value = ""
    } else {
      textarea.disabled = false
      textarea.placeholder = ""
      textarea.value = yaml.dump(inputExamples, {'lineWidth': 124})
    }

    resize(textarea)
  }, [metadata]);

  return <textarea ref={textareaRef} className="inputFile" type="text"
    onInput={(e) => resize(e.target)}></textarea>;
})

// https://stackoverflow.com/a/34491966/3519951
function isEmptyObject(obj) { 
  for (var _ in obj) { return false; }
  return true;
}
