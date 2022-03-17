/**
 * BON in a Box - Script service
 */
package org.openapitools.server.apis

import io.ktor.application.*
import io.ktor.http.*
import io.ktor.locations.*
import io.ktor.request.*
import io.ktor.response.*
import io.ktor.routing.*
import org.geobon.pipeline.ConstantPipe
import org.geobon.pipeline.ScriptStep
import org.geobon.pipeline.Step
import org.geobon.script.ScriptRun
import org.geobon.script.scriptRoot
import org.openapitools.server.Paths
import org.slf4j.Logger
import java.io.File

/**
 * Used to transport paths through path param.
 * Folder tree not supported, see https://github.com/OAI/OpenAPI-Specification/issues/892
 */
const val FILE_SEPARATOR = '>'

val runningPipelines = mutableMapOf<String, Step>()

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
        script.result?.let { call.respond(HttpStatusCode.OK, it) }
            ?: call.respond(HttpStatusCode.InternalServerError)
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
        call.respond(listOf("hard-coded"))
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
        logger.info("pipeline: ${parameters.descriptionPath}\nbody:$inputFileContent")
        // TODO some real implementation

        try {
            // Launch fake pipeline
            val step1 = ScriptStep("HelloWorld/HelloPython.yml", mapOf("some_int" to ConstantPipe("int", 12))) // 12
            val step2 = ScriptStep("HelloWorld/HelloPython.yml", mapOf("some_int" to step1.outputs["increment"]!!)) // 13
            val finalStep = ScriptStep("HelloWorld/HelloPython.yml", mapOf("some_int" to step2.outputs["increment"]!!)) // 14
            runningPipelines["fakePath"] = finalStep
            finalStep.outputs["increment"]!!.pull()
            // runningPipelines.remove("fakePath")

            // Output dump for debugging :
            logger.trace("""
                step1: ${step1.outputs}
                step2: ${step2.outputs}
                finalStep: ${finalStep.outputs}
            """.trimIndent())

            call.respondText("fakePath")
        } catch (ex:Exception) {
            call.respondText(ex.stackTraceToString(), status=HttpStatusCode.InternalServerError)
        }

    }

    get<Paths.getPipelineOutputs> { parameters ->
        runningPipelines[parameters.id]?.let { finalStep -> // Return live result
            val allOutputs = mutableMapOf<String, String>()
            finalStep.dumpOutputFolders(allOutputs)
            call.respond(allOutputs)
        } ?: call.respondText("Unimplemented: only hardcoded result can be retrieved") // TODO: Get the file

        // TODO some real implementation
    }

}