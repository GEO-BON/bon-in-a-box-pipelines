package org.geobon.pipeline

/**
 * Id for an input or outputString
 * @param {String} step
 * @param {String} nodeId
 * @param {String} inputOrOutput Optional, id of input or output in the yaml. Null for pipeline inputs.
 */
data class IOId(val step: StepId, val inputOrOutput: String? = null) {

    /**
     * Get an IOId for a pipeline, from the pipeline's ID and the IOId of the step.
     */
    constructor(pipelineId: StepId, stepIoId:IOId) : this(pipelineId, stepIoId.toString())

    override fun toString(): String {
        return "${step.toString()}" + (if (inputOrOutput == null) "" else "|$inputOrOutput")
    }

    fun toBreadcrumbs(): String {
        return "${step.toBreadcrumbs()}" + (if (inputOrOutput == null) "" else "|$inputOrOutput")
    }
}

data class StepId(val step: String, val nodeId: String, val parent:StepId? = null) {
    override fun toString(): String {
        return 
            if(parent == null && step.isEmpty() && nodeId.isEmpty()) "" // Special case for root pipeline
            else "$step@$nodeId"
    }

    fun toBreadcrumbs(): String {
        return 
            if(parent == null) toString() 
            else "${parent.toBreadcrumbs()}|${toString()}"
    }
}

// -- The util functions below have a mirror in JS UI code.

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
    return if (lastPipe == -1) str else str.substring(lastPipe + 1) // script
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
        if (firstPipe == -1) ioId.length else firstPipe
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
        if (firstPipe == -1) ioId.length else firstPipe
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
    if (pipeIx == -1)
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