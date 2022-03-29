/**
 * BON in a Box - Script service
 */
package org.openapitools.server.apis

import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import io.ktor.application.*
import io.ktor.http.*
import io.ktor.locations.*
import io.ktor.request.*
import io.ktor.response.*
import io.ktor.routing.*
import kotlinx.coroutines.launch
import org.geobon.pipeline.ConstantPipe
import org.geobon.pipeline.ScriptStep
import org.geobon.pipeline.Step
import org.geobon.script.ScriptRun
import org.geobon.script.outputRoot
import org.geobon.script.scriptRoot
import org.openapitools.server.Paths
import org.openapitools.server.utils.toMD5
import org.slf4j.Logger
import java.io.File

/**
 * Used to transport paths through path param.
 * Folder tree not supported, see https://github.com/OAI/OpenAPI-Specification/issues/892
 */
const val FILE_SEPARATOR = '>'

val runningPipelines = mutableMapOf<String, Step>()

private fun getLiveOutput(step: Step): Map<String, String> {
    val allOutputs = mutableMapOf<String, String>()
    step.dumpOutputFolders(allOutputs)
    return allOutputs.mapKeys { it.key.replace('/', FILE_SEPARATOR) }
}

private val gson = Gson()

@KtorExperimentalLocationsAPI
fun Route.ScriptApi(logger:Logger) {

    get<Paths.getScriptInfo> { parameters ->
        try {
            // Put back the slashes and replace extension by .yml
            val ymlPath = parameters.scriptPath.replace(FILE_SEPARATOR, '/').replace(Regex("""\.\w+$"""), ".yml")
            val scriptFile = File(scriptRoot, ymlPath)
            call.respondText(scriptFile.readText())
            logger.trace("200: Paths.getScriptInfo $scriptFile")
        } catch (ex:Exception) {
            call.respondText(text=ex.message!!, status=HttpStatusCode.NotFound)
            logger.trace("Error 404: Paths.getScriptInfo ${parameters.scriptPath}")
        }
    }

    post<Paths.runScript> { parameters ->
        val inputFileContent = call.receive<String>()
        logger.info("scriptPath: ${parameters.scriptPath}\nbody:$inputFileContent")

        val scriptRelPath = parameters.scriptPath.replace(FILE_SEPARATOR, '/')
        val script = ScriptRun(File(scriptRoot, scriptRelPath), inputFileContent)
        script.execute()
        call.respond(HttpStatusCode.OK, script.result)
    }

    get<Paths.scriptListGet> {
        val possible = mutableListOf<String>()
        val relPathIndex = scriptRoot.absolutePath.length + 1
        scriptRoot.walkTopDown().forEach { file ->
            if(file.extension == "yml") {
                // Add the relative path, without the script root.
                possible.add(file.absolutePath.substring(relPathIndex).replace('/', FILE_SEPARATOR))
            }
        }
        
        call.respond(possible)
    }

    get<Paths.pipelineListGet> {
        // TODO some real implementation
        call.respond(listOf("hard-coded", "something else"))
/*
        val possible = mutableListOf<String>()
        val relPathIndex = scriptRoot.absolutePath.length + 1
        scriptRoot.walkTopDown().forEach { file ->
            if(file.extension == "yml") {
                // Add the relative path, without the script root.
                possible.add(file.absolutePath.substring(relPathIndex).replace('/', FILE_SEPARATOR))
            }
        }

        call.respond(possible)*/
    }

    get<Paths.getPipelineInfo> { parameters ->
        // TODO some real implementation
        call.respondText("Currently, only a hard-coded pipeline is available.")
        /*
        try {
            // Put back the slashes and replace extension by .yml
            val ymlPath = parameters.scriptPath.replace(FILE_SEPARATOR, '/').replace(Regex("""\.\w+$"""), ".yml")
            val scriptFile = File(scriptRoot, ymlPath)
            call.respondText(scriptFile.readText())
            logger.trace("200: Paths.getScriptInfo $scriptFile")
        } catch (ex:Exception) {
            call.respondText(text=ex.message!!, status=HttpStatusCode.NotFound)
            logger.trace("Error 404: Paths.getScriptInfo ${parameters.scriptPath}")
        }*/
    }


    post<Paths.runPipeline> { parameters ->
        val inputFileContent = call.receive<String>()
        val descriptionPath = parameters.descriptionPath
        logger.info("Pipeline: $descriptionPath\nBody:$inputFileContent")

        // Unique   to this pipeline                                        and to these params
        val runId = descriptionPath.removeSuffix(".yml") + FILE_SEPARATOR + inputFileContent.toMD5()
        val outputFolder = File(outputRoot, runId.replace(FILE_SEPARATOR, '/'))

        // Launch fake pipeline // TODO read from file
        val step1 = ScriptStep("HelloWorld/HelloPython.yml", mapOf("some_int" to ConstantPipe("int", 12))) // 12
        val step2 = ScriptStep("HelloWorld/HelloPython.yml", mapOf("some_int" to step1.outputs["increment"]!!)) // 13
        val finalStep = ScriptStep("HelloWorld/HelloPython.yml", mapOf("some_int" to step2.outputs["increment"]!!)) // 14

        launch {
            runningPipelines[runId] = finalStep

            try {
                finalStep.outputs["increment"]!!.pull()
            } catch (ex:Exception) {
                logger.error(ex.stackTraceToString())
            } finally {  // Write the results file, adding "not run" to steps that were not run.
                val resultFile = File(outputFolder, "output.json")
                val content = gson.toJson(getLiveOutput(finalStep).mapValues { (_, value) ->
                    if (value == "") "Not run" else value
                })
                println("Outputting to $resultFile")

                outputFolder.mkdirs()
                resultFile.writeText(content)
            }

            runningPipelines.remove(runId)
        }

        call.respondText(runId)
    }

    get<Paths.getPipelineOutputs> { parameters ->
        val finalStep = runningPipelines[parameters.id]
        if(finalStep == null) {
            val outputFolder = File(outputRoot, parameters.id.replace(FILE_SEPARATOR, '/'))
            val outputFile = File(outputFolder, "output.json")
            val type = object : TypeToken<Map<String, Any>>() {}.type
            call.respond(gson.fromJson<Map<String, String>>(outputFile.readText(), type))
        } else {
            call.respond(getLiveOutput(finalStep))
        }
    }

}