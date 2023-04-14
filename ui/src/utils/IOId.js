// This file has a mirror in Kotlin server code.

/**
 * 
 * @param {String} step 
 * @param {String} nodeId 
 * @param {String} inputOrOutput Optional, id of input or output in the yaml. Null for pipeline inputs.
 * @returns the IO id: step@nodeId|inputOrOutput
 */
export function toIOId(step, nodeId, inputOrOutput) {
    return step + '@' + nodeId + (inputOrOutput ? '|' + inputOrOutput : '')
}

/**
 * @returns The path of the script that parses inputs / provides output.
 * 
 * from pipeline.json@12|pipeline.json@23|script.yml@31|output
 * returns script.yml
 * 
 * from script.yml@31|output
 * returns script.yml
 */
export function getScript(ioId) {
    const str = ioId.substring(0, ioId.lastIndexOf('@')) // pipeline@12|pipeline@23|script
    const lastPipe = str.lastIndexOf('|')
    return lastPipe === -1 ? str : str.substring(lastPipe + 1) // script
}

/**
 * @returns The unique identification of this step in the outer pipeline.
 * 
 * from pipeline.json@12|pipeline.json@23|script.yml@31|output
 * returns pipeline.json@12
 * 
 * from script.yml@31
 * returns script.yml@31
 */
export function getStepId(ioId) {
    const firstPipe = ioId.indexOf('|')
    return ioId.substring(
        0,
        firstPipe === -1 ? ioId.length : firstPipe
    )
}

/**
 * @returns Breadcrumbs from the outer pipeline to the script
 * 
 * from pipeline.json@12|pipeline.json@23|script.yml@31|output
 * returns pipeline.json@12|pipeline.json@23|script.yml@31
 * 
 * from pipeline.json@12|pipeline.json@23|script.yml@31
 * returns pipeline.json@12|pipeline.json@23|script.yml@31
 * 
 * from script.yml@31|output
 * returns script.yml@31
 * 
 * from script.yml@31
 * returns script.yml@31
 */
export function getBreadcrumbs(ioId) {
    const lastPipe = ioId.lastIndexOf('|')
    const lastAt = ioId.lastIndexOf('@')
    if(lastAt < lastPipe) {
        return ioId.substring(0, lastPipe)
    }

    return ioId
}

/**
 * @returns The description file for this step in the outer pipeline.
 * 
 * from pipeline.json@12|pipeline.json@23|script.yml@31|output
 * returns pipeline.json
 */
export function getStepFile(ioId) {
    return ioId.substring(0, ioId.indexOf('@'))
}


/**
 * @returns The id of the react-flow node corresponding to this step, in the outer pipeline.
 * 
 * from pipeline.json@12|pipeline.json@23|script.yml@31|output
 * returns 12
 * 
 * from pipeline@12
 * returns 12
 */
export function getStepNodeId(ioId) {
    const firstPipe = ioId.indexOf('|')
    return ioId.substring(
        ioId.indexOf('@') + 1,
        firstPipe === -1 ? ioId.length : firstPipe
    )
}

/**
 * @returns The name of the output of this step.
 * 
 * from pipeline.json@12|pipeline.json@23|script.yml@31|output
 * returns pipeline.json@23|script.yml@31|output
 */
export function getStepOutput(ioId) {
    return ioId.substring(ioId.indexOf('|') + 1)
}

/**
 * @returns Output of the script (as defined in the script's yml)
 * 
 * from pipeline.json@12|pipeline.json@23|script.yml@31|output
 * returns output
 * 
 * from pipeline.json@12|pipeline.json@23|script.yml@31
 * returns ""
 * 
 * from script.yml@31|output
 * returns output
 * 
 * from script.yml@31
 * returns ""
 */
export function getScriptOutput(ioId) {
    const lastPipe = ioId.lastIndexOf('|')
    const lastAt = ioId.lastIndexOf('@')
    if(lastAt < lastPipe) {
        return ioId.substring(lastPipe + 1)
    }

    return ""
}

/**
 * @returns The name of the input of this step.
 * 
 * from pipeline.json@12|pipeline.json@23|script.yml@31|input
 * returns pipeline.json@23|script.yml@31|input
 */
export function getStepInput(ioId) {
    return ioId.substring(ioId.indexOf('|') + 1)
}

/**
 * @returns The io id formatted in a human-readable way
 * 
 * from pipeline.json@12|pipeline.json@23|folder>script.yml@31|output
 * returns pipeline | pipeline | folder > script | output
 */
export function toDisplayString(ioId) {
    return ioId.replaceAll(/(.json|.yml)@\d+/g, '').replaceAll('>', ' > ').replaceAll('|', ' | ')
}