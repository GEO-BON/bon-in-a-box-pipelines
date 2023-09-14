import React, { useState } from "react";

/**
 * @returns rendered view of the pipeline inputs and outputs
 */
export const IOList = ({ inputList, outputList, selectedNodes }) => {
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
                  <span className="description">{input.description}</span>
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
                  <span className="description">{output.description}</span>
                </p>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};
