package org.geobon.pipeline

import org.geobon.pipeline.RunContext.Companion.scriptRoot
import org.geobon.script.Description.SCRIPT
import org.geobon.script.ScriptRun
import java.io.File


class ScriptStep(yamlFile: File, inputs: MutableMap<String, Pipe> = mutableMapOf()) :
    YMLStep(yamlFile, inputs = inputs) {

    constructor(fileName: String, inputs: MutableMap<String, Pipe> = mutableMapOf()) : this(
        File(scriptRoot, fileName),
        inputs
    )

    override fun validateGraph(): String {
        if (!yamlFile.exists())
            return "Description file not found: ${yamlFile.path}"

        return super.validateGraph()
    }

    override suspend fun execute(resolvedInputs: Map<String, Any>): Map<String, Any> {
        val scriptFile = File(yamlFile.parent, yamlParsed[SCRIPT].toString())
        val scriptRun = ScriptRun(scriptFile, resolvedInputs.toSortedMap(), context!!)

        scriptRun.execute()

        if (scriptRun.results.containsKey(ScriptRun.ERROR_KEY))
            throw RuntimeException("Script run detected an error: ${scriptRun.results[ScriptRun.ERROR_KEY]}")

        return scriptRun.results
    }

    override fun toString(): String {
        return "ScriptStep(yamlFile=$yamlFile)"
    }

}
