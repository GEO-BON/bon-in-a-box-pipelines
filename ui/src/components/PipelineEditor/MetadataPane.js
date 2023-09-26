import React, { useEffect, useState } from "react";
import Editor from '@monaco-editor/react';

// TODO: See https://github.com/suren-atoyan/monaco-react for configuration
// TODO: Try this for code validation: https://github.com/suren-atoyan/monaco-react/issues/228#issuecomment-1159365104
// TODO: Split the editor in a separate bundle. It's quite heavy and not needed when running the pipeline... 

const emptyMetadata = `name: # short name, such as My Script
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
  const [loaded, setLoaded] = useState(false);

  function handleEditorChange(value, _) {
    setMetadata(value)
  }

  // Avoid loading the editor until it's opened. Then we keep it open or else the sliding animation looks weird.
  useEffect(()=>{
    if(!collapsedPane) {
      setLoaded(true)
    }
  }, [collapsedPane, setLoaded])

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
      {loaded &&
        <div className="rightPaneInner">
          <Editor
            defaultLanguage="yaml"
            value={metadata === "" ? emptyMetadata : metadata}
            onChange={handleEditorChange}
            options={{
              lineNumbers: "off",
              minimap: { enabled: false },
            }}
          />
        </div>
      }
    </div>
  );
};
