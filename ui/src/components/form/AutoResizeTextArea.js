import React, { useRef, useEffect } from 'react';

const yaml = require('js-yaml');

export const AutoResizeTextArea = (({data, setData}) => {
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
    const textarea = textareaRef.current;
    if(isEmptyObject(data)) {
      textarea.disabled = true
      textarea.placeholder = "No inputs"
      textarea.value = ""
    } else {
      textarea.disabled = false
      textarea.placeholder = ""
      textarea.value = yaml.dump(data,
        {
          'lineWidth': 124,
          'sortKeys': true
        })
    }

    resize(textarea)
  }, [data]);

  return <textarea ref={textareaRef} className="inputFile" type="text"
    onInput={(e) => resize(e.target)} 
    onBlur={(e) => setData(yaml.load(e.target.value))}>
    </textarea>;
})

// https://stackoverflow.com/a/34491966/3519951
function isEmptyObject(obj) { 
  for (var _ in obj) { return false; }
  return true;
}
