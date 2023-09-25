import React, { useState } from "react";
import Editor from '@monaco-editor/react';

const yaml = require('js-yaml');

// TODO: See https://github.com/suren-atoyan/monaco-react for configuration

/**
 * @returns rendered view of the pipeline inputs and outputs
 */
export const MetadataPane = ({
  metadata
}) => {
  const [collapsedPane, setCollapsedPane] = useState(true);
  return (
    <div className={`rightPane metadataPane ${collapsedPane ? "paneCollapsed" : "paneOpen"}`}>
      <div className="collapseTab" onClick={() => setCollapsedPane(!collapsedPane)}>
        <>
          {collapsedPane ? <>&lt;&lt;</> : <>&gt;&gt;</>}
          <span className="topToBottomText">
            &nbsp;&nbsp;
            Metadata
          </span>
        </>
      </div>
      <div className="rightPaneInner">
        <Editor
          defaultLanguage="yaml"
          defaultValue={yaml.dump(metadata)}
          options={{
            lineNumbers:"off",
            minimap: { enabled: false },
          }}
        />
      </div>
    </div>
  );
};
