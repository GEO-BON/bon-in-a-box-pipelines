package org.geobon.pipeline

import org.geobon.pipeline.RunContext.Companion.scriptRoot
import org.geobon.script.Description.SCRIPT
import org.geobon.script.Description.TIMEOUT
import org.geobon.script.ScriptRun
import org.geobon.script.ScriptRun.Companion.DEFAULT_TIMEOUT
import java.io.File
import kotlin.time.Duration.Companion.minutes


class ScriptStep(yamlFile: File, stepId: StepId, inputs: MutableMap<String, Pipe> = mutableMapOf()) :
    YMLStep(yamlFile, stepId, inputs = inputs) {

    constructor(fileName: String, stepId: StepId, inputs: MutableMap<String, Pipe> = mutableMapOf()) : this(
        File(scriptRoot, fileName),
        stepId,
        inputs
    )

    override fun validateGraph(): String {
        if (!yamlFile.exists())
            return "Description file not found: ${yamlFile.path}"

        return super.validateGraph()
    }

    override suspend fun execute(resolvedInputs: Map<String, Any>): Map<String, Any> {
        val scriptFile = File(yamlFile.parent, yamlParsed[SCRIPT].toString())
        val specificTimeout = (yamlParsed[TIMEOUT] as? Int)?.minutes

        var runOwner = false
        val scriptRun = synchronized(currentRuns) {
            currentRuns.getOrPut(context!!.runId) {
                runOwner = true
                ScriptRun(scriptFile, resolvedInputs.toSortedMap(), context!!, specificTimeout ?: DEFAULT_TIMEOUT)
            }
        }
        
        if(runOwner) {
            scriptRun.execute()
            synchronized(currentRuns) {
                currentRuns.remove(context!!.runId)
            }
        } else {
            scriptRun.waitForResults()
        }

        if (scriptRun.results.containsKey(ScriptRun.ERROR_KEY))
            throw RuntimeException("Script run detected an error: ${scriptRun.results[ScriptRun.ERROR_KEY]}")

        return scriptRun.results
    }

    override fun toString(): String {
        return "ScriptStep(yamlFile=$yamlFile)"
    }

    companion object {
        val currentRuns = mutableMapOf<String, ScriptRun>()
    }

}
