import { useState } from "react";
import RenderedMap from './RenderedMap';
import React from 'react';
import RenderedCSV from './csv/RenderedCSV';
import { FoldableOutput, RenderContext, createContext } from "./FoldableOutput";

export function Result({data, metadata, logs}) {
    const [activeRenderer, setActiveRenderer] = useState({});

    if (data || logs) {
        return (
            <div>
                <RenderContext.Provider value={createContext(activeRenderer, setActiveRenderer)}>
                    <RenderedFiles key="files" files={data} metadata={metadata} />
                    <RenderedLogs key="logs" logs={logs} />
                </RenderContext.Provider>
            </div>
        );
    }

    return null;
}

function RenderedFiles({files, metadata}) {

    function renderWithMime(key, content) {
        let mime = ""
        let error = ""
        if (metadata && metadata.outputs) {
            if (metadata.outputs[key]) {
                if (metadata.outputs[key].type) {
                    mime = metadata.outputs[key].type;
                } else {
                    error = "Missing mime type in output description."
                }
            } else {
                error = "Output description not found in this script's YML description file."
            }
        } else {
            error = "YML description file for this script specifies no output."
        }

        // Special case for arrays
        if(mime.endsWith('[]'))
            return <p>{content.join(', ')}</p>

        let [type, subtype] = mime.split('/');
        switch (type) {
            case "image":
                // Match many MIME type possibilities for geotiffs
                // Official IANA format: image/tiff; application=geotiff
                // Others out there: image/geotiff, image/tiff;subtype=geotiff, image/geo+tiff
                // See https://github.com/opengeospatial/geotiff/issues/34
                // Plus covering a common typo when second F omitted
                if (subtype && subtype.includes("tif") && subtype.includes("geo")) {
                    return <RenderedMap tiff={content} />;
                }
                return <img src={content} alt={key} />;

            case "text":
                if (subtype === "csv")
                    return <RenderedCSV url={content} delimiter="," />;
                if (subtype === "tab-separated-values")
                    return <RenderedCSV url={content} delimiter="&#9;" />;
                else
                    return <p>{content}</p>;

            case "":
                return <>
                    <p className="error">{error}</p>
                    {// Fallback code to render the best we can. This can be useful if temporary outputs are added when debugging a script.
                        isRelativeLink(content) ? (
                            // Match for tiff, TIFF, tif or TIF extensions
                            content.search(/.tiff?$/i) !== -1 ? (
                                <RenderedMap tiff={content} />
                            ) : (
                                <img src={content} alt={key} />
                            )
                        ) : ( // Plain text or numeric value
                            <p>{content}</p>
                        )}
                </>;

            default:
                return <p>{content}</p>;
        }
    }

    function renderInline(content){
        return Array.isArray(content) ? content.join(', ') : content
    }

    if (files) {
        return Object.entries(files).map(entry => {
            const [key, value] = entry;

            if (key === "warning" || key === "error") {
                return value && <p key={key} className={key}>{value}</p>;
            }

            let title = key;
            let description = null;
            if (metadata
                && metadata.outputs
                && metadata.outputs[title]) {
                let output = metadata.outputs[title];
                if (output.label)
                    title = output.label;

                if (output.description)
                    description = output.description;
            }

            let isLink = isRelativeLink(value)
            return (
                <FoldableOutput key={key} title={title} description={description} componentId={key}
                    inline={isLink && <a href={value} target="_blank" rel="noreferrer">{value}</a>}
                    inlineCollapsed={!isLink && renderInline(value)}
                    className="foldableOutput">
                    {renderWithMime(key, value)}
                </FoldableOutput>
            );
        });
    } else {
        return null;
    }
}

function RenderedLogs({logs}) {
    const myId = "logs";

    if (logs) {
        return (
            <FoldableOutput title="Logs" componentId={myId} className="foldableOutput">
                <pre>{logs}</pre>
            </FoldableOutput>
        );
    }
    return null;
}


function isRelativeLink(value) {
    if (typeof value.startsWith === "function") { 
        return value.startsWith('/')
    }
    return false
}
