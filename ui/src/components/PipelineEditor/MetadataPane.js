import React, { useState } from "react";

/**
 * @returns rendered view of the pipeline inputs and outputs
 */
export const MetadataPane = ({
  metadata
}) => {
  const [collapsedPane, setCollapsedPane] = useState(false);
  return (
    <div className={`rightPane metadataPane ${collapsedPane ? "paneCollapsed" : "paneOpen"}`}>
      <div className="collapseTab" onClick={() => setCollapsedPane(!collapsedPane)}>
        {collapsedPane ?
          <>
            &lt;&lt;
            <span className="topToBottomText">
              &nbsp;&nbsp;
              Metadata
            </span>
          </>
          : ">>"}
      </div>
      <div className="rightPaneInner">
        <h3>Metadata</h3>
        <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc at egestas dui. Sed accumsan felis eget mi congue, id suscipit elit dictum. Proin lorem nunc, scelerisque at diam ut, vehicula aliquam magna. Duis non nunc elementum, bibendum enim a, imperdiet nulla. Duis odio nisi, porttitor non imperdiet at, fringilla ac nisi. Sed dictum neque lectus, ut suscipit tortor accumsan a. Mauris vehicula semper eleifend. Aenean urna dui, vulputate quis viverra sit amet, cursus placerat neque.</p>
        <p>Quisque vestibulum luctus urna vitae luctus. Nunc eget mauris metus. Sed ipsum erat, aliquam ac viverra ut, convallis id ante. Nam aliquet et sem ut volutpat. Aliquam at ullamcorper tortor, quis eleifend nunc. Suspendisse efficitur nisl in erat fermentum, et congue arcu fermentum. In ut diam sed nulla tincidunt scelerisque. Fusce congue aliquet nibh, in viverra ipsum auctor sit amet. Proin auctor sapien dolor, ut dignissim leo auctor a. </p>
      </div>
    </div>
  );
};
