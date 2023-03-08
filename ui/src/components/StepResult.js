import { useState } from "react";
import Map from './map/Map';
import React from 'react';
import RenderedCSV from './csv/RenderedCSV';
import { FoldableOutputWithContext, RenderContext, createContext, FoldableOutput } from "./FoldableOutput";

export function StepResult({data, metadata, logs}) {
    const [activeRenderer, setActiveRenderer] = useState({});

    return (data || logs) && (
        <div>
            <RenderContext.Provider value={createContext(activeRenderer, setActiveRenderer)}>
                <AllOutputsResults key="files" files={data} stepMetadata={metadata} />
                <Logs key="logs" logs={logs} />
            </RenderContext.Provider>
        </div>
    );
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
    if(isRelativeLink(content) || (typeof content.startsWith === "function" && content.startsWith("http"))) {
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

function AllOutputsResults({ files, stepMetadata }) {
    return files && Object.entries(files).map(entry => {
        const [key, value] = entry;

        if (key === "warning" || key === "error" || key === "info") {
            return value && <p key={key} className={key}>{value}</p>;
        }

        const outputMetadata = stepMetadata && stepMetadata.outputs && stepMetadata.outputs[key]

        return <SingleOutputResult key={key} outputId={key} outputValue={value} outputMetadata={outputMetadata} />
    });
}

export function SingleOutputResult({ outputId, outputValue, outputMetadata }) { 

    function renderContent(content) {
        let error = ""
        if (outputMetadata) {
            if (outputMetadata.type) { // Got our mime type!
                return renderWithMime(content, outputMetadata.type)
            } else {
                error = "Missing mime type in output description."
            }
        } else {
            error = "Output description not found in this script's YML description file."
        }


        return <>
            <p className="error">{error}</p>
            <FallbackDisplay content={content} />
        </>;
    }

    function renderWithMime(content, mime) {
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
                        {renderWithMime(splitContent, splitMime)}
                    </FoldableOutput>
                })

            } else { // Trivial types are printed with a comma
                return <p>{content.join(', ')}</p>
            }
        }


        switch (type) {
            case "image":
                if (isGeotiff(subtype)) {
                    return <Map tiff={content} range={outputMetadata.range} />
                }
                return <img src={content} alt={outputMetadata.label} />;

            case "text":
                if (subtype === "csv")
                    return <RenderedCSV url={content} delimiter="," />;
                if (subtype === "tab-separated-values")
                    return <RenderedCSV url={content} delimiter="&#9;" />;
                
                break;

            case "object":
                return Object.entries(content).map(entry => {
                    const [key, value] = entry;
                    let isLink = isRelativeLink(value)
                    return <FoldableOutput key={key} title={key}
                        inline={isLink && <a href={value} target="_blank" rel="noreferrer">{value}</a>}
                        inlineCollapsed={!isLink && renderInline(value)}
                        className="foldableOutput">
                        {renderWithMime(value, "unknown")}
                    </FoldableOutput>
                })

            case "application":
                if (subtype === "geo+json")
                    return <Map json={content} />

                break;

            case "unknown":
            default:
                return <FallbackDisplay content={content} />

        }

        return <p className="resultText">{content}</p>;
    }

    function renderInline(content){
        if(typeof content === 'object')
            content = Object.keys(content)

        return Array.isArray(content) ? content.join(', ') : content
    }

    let title = outputId;
    let description = null;
    if (outputMetadata) {
        if (outputMetadata.label)
            title = outputMetadata.label;

        if (outputMetadata.description)
            description = <p className="outputDescription">{outputMetadata.description}</p>;
    }

    let isLink = isRelativeLink(outputValue)
    return (
        <FoldableOutputWithContext key={outputId} title={title} componentId={outputId}
            inline={isLink && <a href={outputValue} target="_blank" rel="noreferrer">{outputValue}</a>}
            inlineCollapsed={!isLink && renderInline(outputValue)}
            className="foldableOutput">
            {description}
            {renderContent(outputValue)}
        </FoldableOutputWithContext>
    );
}

function Logs({ logs }) {
    if (!logs)
        return null;

    const myId = "logs";
    return (
        <FoldableOutputWithContext title="Logs" componentId={myId} className="foldableOutput">
            <pre>{logs}</pre>
        </FoldableOutputWithContext>
    );
}


function isRelativeLink(value) {
    if (value && typeof value.startsWith === "function") { 
        return value.startsWith('/')
    }
    return false
}
