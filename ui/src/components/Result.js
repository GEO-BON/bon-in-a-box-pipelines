import { useState } from "react";
import Map from './Map';
import React from 'react';
import RenderedCSV from './csv/RenderedCSV';
import { FoldableOutputWithContext, RenderContext, createContext, FoldableOutput } from "./FoldableOutput";

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

/**
 * Match many MIME type possibilities for geotiffs
 * Official IANA format: image/tiff; application=geotiff
 * Others out there: image/geotiff, image/tiff;subtype=geotiff, image/geo+tiff
 * See https://github.com/opengeospatial/geotiff/issues/34
 * Plus covering a common typo when second F omitted
 * 
 * @param {string} mime subtype 
 * @return True if subtype image is a geotiff
 */
function isGeotiff(subtype) {
    return subtype && subtype.includes("tif") && subtype.includes("geo")
}

// Fallback code to render the best we can. This can be useful if temporary outputs are added when debugging a script.
function FallbackDisplay({content}) {
    if(isRelativeLink(content) || content.startsWith("http")) {
        // Match for tiff, TIFF, tif or TIF extensions
        if(content.search(/.tiff?$/i) !== -1)
            return <Map tiff={content} />
        else if(content.search(/.csv$/i))
            return <RenderedCSV url={content} delimiter="," />
        else if(content.search(/.tsv$/i))
            return <RenderedCSV url={content} delimiter="&#9;" />
        else 
            return <img src={content} alt={content} />
    }

    // Plain text or numeric value
    return <p className="resultText">{content}</p>    
}

function RenderedFiles({files, metadata}) {

    function renderContent(outputKey, content) {
        let error = ""
        if (metadata && metadata.outputs) {
            if (metadata.outputs[outputKey]) {
                if (metadata.outputs[outputKey].type) { // Got our mime type!
                    return renderWithMime(outputKey, content, metadata.outputs[outputKey].type)
                } else {
                    error = "Missing mime type in output description."
                }
            } else {
                error = "Output description not found in this script's YML description file."
            }
        } else {
            error = "YML description file for this script specifies no output."
        }

        return <>
            <p className="error">{error}</p>
            <FallbackDisplay content={content} />
        </>;
    }

    function renderWithMime(outputKey, content, mime) {
        let [type, subtype] = mime.split('/');

        // Special case for arrays. Recursive call to render non-trivial types.
        if (mime.endsWith('[]') && Array.isArray(content)) {
            if (type === "image"
                || mime.startsWith("text/csv")
                || mime.startsWith("text/tab-separated-values")) {

                let splitMime = mime.slice(0, -2);
                return content.map((splitContent, i) => {
                    return <FoldableOutput key={i}
                        inline={<a href={splitContent} target="_blank" rel="noreferrer">{splitContent}</a>}
                        className="foldableOutput">
                        {renderWithMime(outputKey, splitContent, splitMime)}
                    </FoldableOutput>
                })

            } else { // Trivial types are printed with a comma
                return <p>{content.join(', ')}</p>
            }
        }


        switch (type) {
            case "image":
                if (isGeotiff(subtype)) {
                    return <Map tiff={content} range={metadata.outputs[outputKey].range} />;
                }
                return <img src={content} alt={outputKey} />;

            case "text":
                if (subtype === "csv")
                    return <RenderedCSV url={content} delimiter="," />;
                if (subtype === "tab-separated-values")
                    return <RenderedCSV url={content} delimiter="&#9;" />;
                else
                    return <p className="resultText">{content}</p>;

            case "object":
                return Object.entries(content).map(entry => {
                    console.log("entry", entry)
                    const [key, value] = entry;
                    let isLink = isRelativeLink(value)
                    return <FoldableOutput key={key} title={key}
                        inline={isLink && <a href={value} target="_blank" rel="noreferrer">{value}</a>}
                        inlineCollapsed={!isLink && renderInline(value)}
                        className="foldableOutput">
                        {renderWithMime(outputKey, value, "unknown")}
                    </FoldableOutput>
                })

            case "unknown":
                return <FallbackDisplay content={content} />

            default:
                return <p className="resultText">{content}</p>;
        }
    }

    function renderInline(content){
        if(typeof content === 'object')
            content = Object.keys(content)

        return Array.isArray(content) ? content.join(', ') : content
    }

    if (files) {
        return Object.entries(files).map(entry => {
            const [key, value] = entry;

            if (key === "warning" || key === "error" || key === "info") {
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
                <FoldableOutputWithContext key={key} title={title} description={description} componentId={key}
                    inline={isLink && <a href={value} target="_blank" rel="noreferrer">{value}</a>}
                    inlineCollapsed={!isLink && renderInline(value)}
                    className="foldableOutput">
                    {renderContent(key, value)}
                </FoldableOutputWithContext>
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
            <FoldableOutputWithContext title="Logs" componentId={myId} className="foldableOutput">
                <pre>{logs}</pre>
            </FoldableOutputWithContext>
        );
    }
    return null;
}


function isRelativeLink(value) {
    if (value && typeof value.startsWith === "function") { 
        return value.startsWith('/')
    }
    return false
}
