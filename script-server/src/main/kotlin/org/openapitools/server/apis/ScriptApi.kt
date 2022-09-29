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
import org.geobon.pipeline.EDGES_LIST
import org.geobon.pipeline.NODES_LIST
import org.geobon.pipeline.Pipeline
import org.geobon.pipeline.VIEWPORT
import org.geobon.script.ScriptRun
import org.geobon.script.ScriptRun.Companion.scriptRoot
import org.geobon.script.outputRoot
import org.json.JSONObject
import org.openapitools.server.Paths
import org.openapitools.server.models.ScriptRunResult
import org.openapitools.server.utils.toMD5
import org.slf4j.Logger
import org.yaml.snakeyaml.Yaml
import java.io.File


/**
 * Used to transport paths through path param.
 * Folder tree not supported, see https://github.com/OAI/OpenAPI-Specification/issues/892
 */
const val FILE_SEPARATOR = '>'

private val gson = Gson()
private val pipelinesRoot = File(System.getenv("PIPELINES_LOCATION"))

private val runningPipelines = mutableMapOf<String, Pipeline>()

private fun getLiveOutput(pipeline: Pipeline): Map<String, String> {
    val allOutputs = mutableMapOf<String, String>()
    pipeline.dumpOutputFolders(allOutputs)
    return allOutputs.mapKeys { it.key.replace('/', FILE_SEPARATOR) }
}

@KtorExperimentalLocationsAPI
fun Route.ScriptApi(logger: Logger) {

    get<Paths.getScriptInfo> { parameters ->
        try {
            // Put back the slashes and replace extension by .yml
            val ymlPath = parameters.scriptPath.replace(FILE_SEPARATOR, '/').replace(Regex("""\.\w+$"""), ".yml")
            val scriptFile = File(scriptRoot, ymlPath)
            if (scriptFile.exists()) {
                call.respond(Yaml().load(scriptFile.readText()) as Map<String, Any>)
            } else {
                call.respondText(text = "$scriptFile does not exist", status = HttpStatusCode.NotFound)
                logger.trace("404: Paths.getPipelineInfo ${parameters.scriptPath}")
            }
        } catch (ex: Exception) {
            call.respondText(text = ex.message!!, status = HttpStatusCode.InternalServerError)
            ex.printStackTrace()
        }
    }

    post<Paths.runScript> { parameters ->
        val inputFileContent = call.receive<String>()
        logger.info("scriptPath: ${parameters.scriptPath}\nbody:$inputFileContent")

        val scriptRelPath = parameters.scriptPath.replace(FILE_SEPARATOR, '/')
        val run = ScriptRun(File(scriptRoot, scriptRelPath), inputFileContent)
        run.execute()
        call.respond(
            HttpStatusCode.OK, ScriptRunResult(
                run.logFile.readText(),
                run.results
            )
        )
    }

    get<Paths.scriptListGet> {
        val possible = mutableListOf<String>()
        val relPathIndex = scriptRoot.absolutePath.length + 1
        scriptRoot.walkTopDown().forEach { file ->
            if (file.extension == "yml") {
                // Add the relative path, without the script root.
                possible.add(file.absolutePath.substring(relPathIndex).replace('/', FILE_SEPARATOR))
            }
        }

        call.respond(possible)
    }

    get<Paths.pipelineListGet> {
        val possible = mutableListOf<String>()
        val relPathIndex = pipelinesRoot.absolutePath.length + 1
        pipelinesRoot.walkTopDown().forEach { file ->
            if (file.extension == "json") {
                // Add the relative path, without the script root.
                possible.add(file.absolutePath.substring(relPathIndex).replace('/', FILE_SEPARATOR))
            }
        }

        call.respond(possible)
    }

    get<Paths.getPipelineInfo> { parameters ->
        try {
            // Put back the slashes before reading
            val descriptionFile = File(pipelinesRoot, parameters.descriptionPath.replace(FILE_SEPARATOR, '/'))
            if (descriptionFile.exists()) {
                val descriptionJSON = JSONObject(descriptionFile.readText()).apply {
                    // Remove the pipeline structure to leave only the metadata
                    remove(NODES_LIST)
                    remove(EDGES_LIST)
                    remove(VIEWPORT)
                }

                call.respondText(descriptionJSON.toString(), ContentType.parse("application/json"))
            } else {
                call.respondText(text = "$descriptionFile does not exist", status = HttpStatusCode.NotFound)
                logger.trace("404: Paths.getPipelineInfo ${parameters.descriptionPath}")
            }
        } catch (ex: Exception) {
            call.respondText(text = ex.message!!, status = HttpStatusCode.InternalServerError)
            ex.printStackTrace()
        }
    }


    post<Paths.runPipeline> { parameters ->
        val inputFileContent = call.receive<String>()
        val descriptionPath = parameters.descriptionPath

        // Unique   to this pipeline                                               and to these params
        val runId = descriptionPath.removeSuffix(".json") + FILE_SEPARATOR + inputFileContent.toMD5()
        val outputFolder = File(outputRoot, runId.replace(FILE_SEPARATOR, '/'))
        logger.info("Pipeline: $descriptionPath\nFolder:$outputFolder\nBody:$inputFileContent")

        try {
            val pipeline = Pipeline(descriptionPath, inputFileContent)
            runningPipelines[runId] = pipeline
            call.respondText(runId)

            launch {
                pipeline.execute()

                val resultFile = File(outputFolder, "output.json")
                val content = gson.toJson(getLiveOutput(pipeline).mapValues { (_, value) ->
                    if (value == "") "skipped" else value
                })
                logger.trace("Outputting to $resultFile")

                outputFolder.mkdirs()
                resultFile.writeText(content)

                runningPipelines.remove(runId)
            }
        } catch (e: Exception) {
            call.respondText(text = e.message ?: "", status = HttpStatusCode.InternalServerError)
            logger.debug(e.message)
        }
    }

    get<Paths.getPipelineOutputs> { parameters ->
        val pipeline = runningPipelines[parameters.id]
        if (pipeline == null) {
            val outputFolder = File(outputRoot, parameters.id.replace(FILE_SEPARATOR, '/'))
            val outputFile = File(outputFolder, "output.json")
            val type = object : TypeToken<Map<String, Any>>() {}.type
            call.respond(gson.fromJson<Map<String, String>>(outputFile.readText(), type))
        } else {
            call.respond(getLiveOutput(pipeline))
        }
    }

    get<Paths.stopPipeline> { parameters ->
        runningPipelines[parameters.id]?.let { pipeline ->
            // the pipeline is running, we need to stop it
            println("Cancelling ${parameters.id}...")
            pipeline.stop()
            println("Cancelled ${parameters.id}")
            call.respond(HttpStatusCode.OK)
        } ?: call.respond(/*412*/HttpStatusCode.PreconditionFailed, "The pipeline wasn't running")
    }

}