import React, { useEffect, useRef } from 'react';

export default function AutoResizeTextArea({defaultValue, keepWidth, className, ...props}) {

  const textAreaRef = useRef(null)

  useEffect(() => {
    resize(textAreaRef.current)
  }, [defaultValue, resize])

  /**
   * Automatic horizontal and vertical resizing of textarea
   * @param {textarea} input
   */
  function resize(input) {
    input.style.height = 0;
    input.style.height = input.scrollHeight + "px";

    if(!keepWidth) {
      input.style.width = "auto";
      input.style.width = input.scrollWidth + "px";
    }
  }

  return <textarea className={(className ? className + ' ' : '') + 'autoResize'} ref={textAreaRef} defaultValue={defaultValue} {...props} 
    onChange={(e) => resize(e.target)} />;
}
