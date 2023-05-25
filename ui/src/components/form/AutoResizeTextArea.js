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
    input.style.height = 0;
    input.style.height = input.scrollHeight + "px";

    input.style.width = "auto";
    input.style.width = input.scrollWidth + "px";
  }

  return <textarea className='autoResize' ref={textAreaRef} defaultValue={defaultValue} {...props} 
    onChange={(e) => resize(e.target)} />;  
}
