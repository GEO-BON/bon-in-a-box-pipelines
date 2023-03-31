package org.geobon.pipeline

// This file has a mirror in JS UI code.

/**
 *
 * @param {String} step
 * @param {String} nodeId
 * @param {String} inputOrOutput Optional, id of input or output in the yaml. Null for pipeline inputs.
 * @returns the IO id: step@nodeId|inputOrOutput
 */
fun toIOId(step: String, nodeId: String, inputOrOutput: String? = null): String {
    return "$step@$nodeId" + (if (inputOrOutput == null) "" else "|$inputOrOutput")
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
fun getScript(ioId: String): String {
    val str = ioId.substring(0, ioId.lastIndexOf('@')) // pipeline@12|pipeline@23|script
    val lastPipe = str.lastIndexOf('|')
    return if(lastPipe == -1) str else str.substring(lastPipe + 1) // script
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
fun getStepId(ioId: String): String {
    val firstPipe = ioId.indexOf('|')
    return ioId.substring(
        0,
        if(firstPipe == -1)  ioId.length else firstPipe
    )
}

/**
 * @returns The description file for this step in the outer pipeline.
 *
 * from pipeline.json@12|pipeline.json@23|script.yml@31|output
 * returns pipeline.json
 */
fun getStepFile(ioId: String): String {
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
fun getStepNodeId(ioId: String): String {
    val firstPipe = ioId.indexOf('|')
    return ioId.substring(
        ioId.indexOf('@') + 1,
        if(firstPipe == -1)  ioId.length else firstPipe
    )
}

/**
 * @returns The name of the output of this step.
 *
 * from pipeline.json@12|pipeline.json@23|script.yml@31|output
 * returns pipeline.json@23|script.yml@31|output
 */
fun getStepOutput(ioId: String): String? {
    val pipeIx = ioId.indexOf('|')
    if(pipeIx == -1)
        return null

    return ioId.substring(pipeIx + 1)
}

/**
 * @returns The name of the input of this step.
 *
 * from pipeline.json@12|pipeline.json@23|script.yml@31|input
 * returns pipeline.json@23|script.yml@31|input
 */
fun getStepInput(ioId: String): String? {
    return getStepOutput(ioId) // same naming convention as outputs
}