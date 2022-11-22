package org.geobon.pipeline

import com.google.gson.Gson
import org.geobon.script.Description.SCRIPT
import org.geobon.script.ScriptRun
import org.geobon.script.ScriptRun.Companion.scriptRoot
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
        val scriptRun = ScriptRun(scriptFile, resolvedInputs.toSortedMap(), outputFolder!!)

        validateInputsReceived(resolvedInputs)?.let { error ->
            val results = mapOf(ScriptRun.ERROR_KEY to error)
            scriptRun.resultFile.parentFile.mkdirs()
            scriptRun.resultFile.writeText(Gson().toJson(results))
            throw RuntimeException(error)
        }

        scriptRun.execute()

        if (scriptRun.results.containsKey(ScriptRun.ERROR_KEY))
            throw RuntimeException("Script run detected an error: ${scriptRun.results[ScriptRun.ERROR_KEY]}")

        return scriptRun.results
    }

    override fun toString(): String {
        return "ScriptStep(yamlFile=$yamlFile)"
    }

}
