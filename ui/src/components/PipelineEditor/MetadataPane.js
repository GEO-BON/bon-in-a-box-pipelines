import React, { useState } from "react";
import Editor from '@monaco-editor/react';

const yaml = require('js-yaml');

// TODO: See https://github.com/suren-atoyan/monaco-react for configuration

const emptyMetadata = `
name: # short name, such as My Script
description: # Targetted to those who will interpret pipeline results and edit pipelines.
author: # 1 to many
  - name: # Full name
    identifier: # Optional, full URL of a unique digital identifier such as an ORCID
license: # Optional. If unspecified, the project's MIT license will apply.
external_link: # Optional, link to a separate project, github repo, etc.
`

/**
 * @returns rendered view of the pipeline inputs and outputs
 */
export const MetadataPane = ({
  metadata, setMetadata
}) => {
  const [collapsedPane, setCollapsedPane] = useState(true);

  function handleEditorChange(value, event) {
    setMetadata(value)
  }

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
          defaultValue={metadata === "" ? emptyMetadata : metadata}
          onChange={handleEditorChange}
          options={{
            lineNumbers:"off",
            minimap: { enabled: false },
          }}
        />
      </div>
    </div>
  );
};
