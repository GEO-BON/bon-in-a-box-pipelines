const yaml = require('js-yaml');

export function StepDescription({ descriptionFile, metadata }) {
    return <>
        <h2>{getFolderAndNameFromMetadata(descriptionFile, metadata)}</h2>
        <GeneralDescription ymlPath={descriptionFile} metadata={metadata} />
        <InputsDescription metadata={metadata} />
        <OutputsDescription metadata={metadata} />
    </>
}

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

    const codeLink = getCodeUrl(ymlPath, metadata.script)
    
    return <div className='stepDescription'>
        {metadata.author &&
            <p>
                <i>
                    {metadata.author.map((author, i, array) => {
                        let comma = (i !== array.length - 1) && ',' // Comma will be inside link but the space outside the link.
                        return author.identifier ?
                            <span key={i}><a href={author.identifier} target="_blank">{author.name}{comma}</a> </span>
                            : <span key={i}>{author.name}{comma} </span>
                    })}
                </i>
            </p>
        }
        {metadata.description && <p>{metadata.description}</p>}
        {codeLink && <p>
                Code: <a href={codeLink} target="_blank">{codeLink.substring(codeLink.search(/(scripts|pipelines)\//))}</a>
            </p>
        }
        {metadata.external_link &&
            <p>See&nbsp;
                <a href={metadata.external_link} target="_blank">{metadata.external_link}</a>
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
        {metadata.license && printLicense(metadata.license)}
    </div>
}


function printLicense(license) {
    switch (license.toUpperCase()) {
        case "CC0":
            return <a href="https://creativecommons.org/publicdomain/zero/1.0/">
                <img alt={license} src="https://mirrors.creativecommons.org/presskit/buttons/88x31/png/cc-zero.png" width="88" height="31" />
            </a>

        case "CC BY":
            return <a href="https://creativecommons.org/licenses/by/4.0/">
                <img alt={license} src="https://mirrors.creativecommons.org/presskit/buttons/88x31/png/by.png" width="88" height="31" />
            </a>

        case "CC BY-SA":
            return <a href="https://creativecommons.org/licenses/by-sa/4.0/">
                <img alt={license} src="https://mirrors.creativecommons.org/presskit/buttons/88x31/png/by-sa.png" width="88" height="31" />
            </a>

        case "CC BY-NC-SA":
            return <a href="https://creativecommons.org/licenses/by-nc-sa/4.0/">
                <img alt={license} src="https://mirrors.creativecommons.org/presskit/buttons/88x31/png/by-nc-sa.png" width="88" height="31" />
            </a>

        case "CC BY-ND":
            return <a href="https://creativecommons.org/licenses/by-nd/4.0/">
                <img alt={license} src="https://mirrors.creativecommons.org/presskit/buttons/88x31/png/by-nd.png" width="88" height="31" />
            </a>

        case "CC BY-NC-ND":
            return <a href="https://creativecommons.org/licenses/by-nc-nd/4.0/">
                <img alt={license} src="https://mirrors.creativecommons.org/presskit/buttons/88x31/png/by-nc-nd.png" width="88" height="31" />
            </a>

        default:
            return <p>License: {license}</p>
    }
}

function getCodeUrl(ymlPath, scriptFileName) {
    if (!ymlPath || !scriptFileName || scriptFileName.endsWith(".kt")) {
        return null
    }

    return 'https://github.com/GEO-BON/biab-2.0/tree/main/scripts/' + removeLastSlash(ymlPath.replaceAll('>', '/')) + scriptFileName 
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