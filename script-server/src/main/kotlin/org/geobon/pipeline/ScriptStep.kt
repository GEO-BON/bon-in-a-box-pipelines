package org.geobon.pipeline

import org.geobon.script.Description.SCRIPT
import org.geobon.script.ScriptRun
import org.geobon.script.scriptRoot
import java.io.File


class ScriptStep(yamlFile: File, inputs: Map<String, Pipe> = mapOf()) :
    YMLStep(yamlString = yamlFile.readText(), inputs = inputs) {

    constructor(fileName:String, inputs: Map<String, Pipe> = mapOf()) : this (File(scriptRoot, fileName), inputs)

    override suspend fun execute(resolvedInputs: Map<String, Any>): Map<String, Any> {
        val scriptFile = File(scriptRoot, yamlParsed[SCRIPT].toString())
        val scriptRun = ScriptRun(
            scriptFile,
            if(resolvedInputs.isEmpty()) null else ScriptRun.toJson(resolvedInputs)
        )
        scriptRun.execute()

        // Get result
        scriptRun.result?.let { result ->
            if (result.error) {
                throw java.lang.Exception("Script run detected an error")
            }

            return result.files ?: throw java.lang.Exception("Output file is empty")
        } ?: throw java.lang.Exception("Script run produced no result")
    }
}
