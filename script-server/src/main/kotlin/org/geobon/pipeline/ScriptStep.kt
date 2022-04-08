package org.geobon.pipeline

import org.geobon.script.Description.SCRIPT
import org.geobon.script.ScriptRun
import org.geobon.script.scriptRoot
import java.io.File


class ScriptStep(val yamlFile: File, inputs: MutableMap<String, Pipe> = mutableMapOf()) :
    YMLStep(yamlString = yamlFile.readText(), inputs = inputs) {

    var runId:String? = null

    constructor(fileName:String, inputs: MutableMap<String, Pipe> = mutableMapOf()) : this (File(scriptRoot, fileName), inputs)

    override fun validateGraph(): String {
        if(!yamlFile.exists())
            return "Description file not found: ${yamlFile.path}"

        return super.validateGraph()
    }

    override suspend fun execute(resolvedInputs: Map<String, Any>): Map<String, Any> {
        val scriptFile = File(yamlFile.parent, yamlParsed[SCRIPT].toString())
        val scriptRun = ScriptRun(
            scriptFile,
            if(resolvedInputs.isEmpty()) null else ScriptRun.toJson(resolvedInputs)
        )
        runId = scriptRun.id
        scriptRun.execute()

        if (scriptRun.results.containsKey(ScriptRun.ERROR_KEY))
            throw java.lang.Exception("Script run detected an error")

        return scriptRun.results
    }

    /**
     * @param allOutputs Map of Step identifier to output folder.
     */
    override fun dumpOutputFolders(allOutputs: MutableMap<String, String>) {
        val relPath = yamlFile.relativeTo(scriptRoot).path
        allOutputs["$relPath@${hashCode()}"] = runId ?: ""
        super.dumpOutputFolders(allOutputs)
    }
}
