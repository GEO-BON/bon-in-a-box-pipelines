package org.geobon.pipeline.teststeps

import org.geobon.pipeline.Output
import org.geobon.pipeline.Pipe
import org.geobon.pipeline.Step
import org.geobon.pipeline.StepId

/**
 * Dummy step for testing purpose: Concatenates all inputs
 */
class ConcatenateStep(
    inputs: MutableMap<String, Pipe>
) : Step(
    StepId("concat", hashCode().toString()),
    inputs,
    mapOf(STRING to Output("text/plain"))
) {

    companion object {
        const val STRING = "concat"
    }

    override suspend fun execute(resolvedInputs: Map<String, Any?>): Map<String, Any?> {
        var resultString  = ""
        resolvedInputs.values.forEach { resultString += it.toString() }
        return mapOf(STRING to resultString)
    }
}