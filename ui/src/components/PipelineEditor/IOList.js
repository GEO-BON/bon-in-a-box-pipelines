import React, { useState } from "react";

/**
 * @returns rendered view of the pipeline inputs and outputs
 */
export const IOList = ({
  inputList,
  setInputList, 
  outputList, 
  setOutputList, 
  selectedNodes
}) => {
  const [collapsedPane, setCollapsedPane] = useState(false);
  return (
    <div className={`ioList ${collapsedPane ? "paneCollapsed" : "paneOpen"}`}>
      <div className="collapseTab" onClick={() => setCollapsedPane(!collapsedPane)}>
        {collapsedPane ?
          <>
            &lt;&lt;
            <span className="topToBottomText">
              &nbsp;&nbsp;
              {inputList.length < 10 && <>&nbsp;</>}
              {inputList.length}&nbsp;Inputs,&nbsp;
              {outputList.length < 10 && <>&nbsp;</>}
              {outputList.length}&nbsp;Outputs
            </span>
          </>
          : ">>"}
      </div>
      <div className="ioListInner">
        <h3>User inputs</h3>
        {inputList.length === 0
          ? "No inputs"
          : inputList.map((input, i) => {
            return (
              <div
                key={i}
                className={selectedNodes.find((node) => node.id === input.nodeId)
                  ? "selected"
                  : ""}
              >
                <p>
                  {input.label}
                  <br />
                  <textarea className="description"
                    onBlur={e => valueEdited(e.target, "description", input, setInputList)}
                    defaultValue={input.description}></textarea>
                </p>
              </div>
            );
          })}
        <h3>Pipeline outputs</h3>
        {outputList.length === 0 ? (
          <p className="error">
            At least one output is needed for the pipeline to run
          </p>
        ) : (
          outputList.map((output, i) => {
            return (
              <div
                key={i}
                className={selectedNodes.find((node) => node.id === output.nodeId)
                  ? "selected"
                  : ""}
              >
                <p>
                  {output.label}
                  <br />
                  <textarea className="description"
                    onBlur={e => valueEdited(e.target, "description", output, setOutputList)}
                    defaultValue={output.description}></textarea>
                </p>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};

function valueEdited(subject, valueKey, io, setter) {
  setter(previousValues => previousValues.map(previousIO => {
    let newIO = {...previousIO}
    if(previousIO.nodeId === io.nodeId
      && previousIO.inputId === io.inputId
      && previousIO.outputId === io.outputId) {
        newIO[valueKey] = subject.value
        console.log("subject.value")
      }

      return newIO
  }))
}