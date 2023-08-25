const yaml = require('js-yaml');

export function getFolderAndNameFromMetadata(ymlPath, metadata) {
    if(!metadata || !metadata.name)
        return ymlPath.replaceAll('>', ' > ').replaceAll('.json', '').replaceAll('.yml', '')

    return getFolderAndName(ymlPath, metadata.name)
}

export function getFolderAndName(ymlPath, name) {
    let split = ymlPath.split('>')
    split[split.length -1] = name
    return split.join(' > ')
}

/**
 * Prints a general description of the script, along with the references.
 * @param {string} Path to the yml script description file
 * @param {object} Script metadata 
*/
export function GeneralDescription({ ymlPath, metadata }) {
    if (!metadata)
        return null

    const codeLink = getCodeLink(ymlPath, metadata.script)

    return <div className='stepDescription'>
        {metadata.description && <p className="outputDescription">{metadata.description}</p>}
        {(metadata.external_link || codeLink) &&
            <p>See&nbsp;
                {metadata.external_link && <a href={metadata.external_link} target="_blank">{metadata.external_link}</a>}
                {metadata.external_link && codeLink && <>&nbsp;and&nbsp;</>}
                {codeLink}
            </p>
        }
        {metadata.references &&
            <div className='references'>
                <p className='noMargin'>References: </p>
                <ul>{metadata.references.map((r, i) => {
                    return <li key={i}>{r.text} {r.doi && <><br /><a href={r.doi} target="_blank">{r.doi}</a></>}</li>
                })}
                </ul>
            </div>
        }
    </div>
}

function getCodeLink(ymlPath, scriptFileName) {
    if (!ymlPath || !scriptFileName || scriptFileName.endsWith(".kt")) {
        return null
    }

    const url = 'https://github.com/GEO-BON/biab-2.0/tree/main/scripts/' + removeLastSlash(ymlPath.replaceAll('>', '/')) + scriptFileName
    return <a href={url} target="_blank">code</a>
}

function removeLastSlash(s) {
    const i = s.lastIndexOf('/');
    if (i === -1) return s
    return s.substring(0, i + 1);
}

/**
 * Prints the inputs from the script metadata.
 * @param {object} Script metadata 
 */
export function InputsDescription({ metadata }) {
    if (!metadata || !metadata.inputs)
        return null

    return <>
        <h3>Inputs</h3>
        <pre>{yaml.dump(metadata.inputs)}</pre>
    </>
}

/**
 * Prints the outputs from the script metadata.
 * @param {object} Script metadata 
 */
export function OutputsDescription({ metadata }) {
    if (!metadata || !metadata.outputs)
        return null

    return <>
        <h3>Outputs</h3>
        <pre>{yaml.dump(metadata.outputs)}</pre>
    </>
}