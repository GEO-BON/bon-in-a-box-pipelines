import React, { useEffect, useRef } from 'react';

export default function AutoResizeTextArea({defaultValue, ...props}) {

  const textAreaRef = useRef(null)

  useEffect(() => {
    resize(textAreaRef.current)
  }, [defaultValue])

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

  return <textarea ref={textAreaRef} defaultValue={defaultValue} {...props} 
    onChange={(e) => resize(e.target)} />;
}
