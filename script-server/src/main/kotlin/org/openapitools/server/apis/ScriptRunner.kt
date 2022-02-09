/**
 * BON in a Box - Script service
 */
package org.openapitools.server.apis

import com.google.gson.Gson
import io.ktor.application.*
import io.ktor.auth.*
import io.ktor.http.*
import io.ktor.response.*
import org.openapitools.server.Paths
import io.ktor.locations.*
import io.ktor.routing.*
import io.ktor.request.receive
import org.openapitools.server.infrastructure.ApiPrincipal
import org.openapitools.server.models.ScriptRunResult
import org.openapitools.server.utils.toMD5
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import java.io.File
import kotlin.collections.joinToString
import kotlin.io.readLine
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.launch
import java.lang.reflect.Type
import java.util.Scanner
import com.google.gson.reflect.TypeToken

val scriptRoot = File(System.getenv("SCRIPT_LOCATION"))
val ouputRoot = File(System.getenv("OUTPUT_LOCATION"))

@KtorExperimentalLocationsAPI
fun Route.ScriptRunner(logger:Logger) {

    val gson = Gson()

    get<Paths.getScriptInfo> { parameters ->
        try {
            // Replace extension by .yml
            val mdPath = parameters.scriptPath.replace(Regex("""\.\w+$"""), ".yml")
            val scriptFile = File(scriptRoot, mdPath)
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

        val scriptFile = File(scriptRoot, parameters.scriptPath)
        if(scriptFile.exists()) {
            // Create the ouput folder based for this invocation
            val outputFolder = getOutputFolder(parameters.scriptPath, inputFileContent)
            outputFolder.mkdirs()
            logger.trace("Paths.runScript outputting to $outputFolder")

            // Run the script
            var error = false
            var logs:String = ""
            var outputs:Map<String, String>? = null

            val resultFile = File(outputFolder, "output.json")
            runCatching {
                // Remove previous run result
                if(resultFile.delete()) {
                    logger.trace("Previous results deleted")
                }

                // Create input.json
                val inputFile=File(outputFolder, "input.json")
                inputFile.writeText(inputFileContent)

                val command = when (scriptFile.extension) {
                    "jl", "JL" -> "julia"
                    "r", "R" -> "Rscript"
                    else -> {
                        call.respond(
                                HttpStatusCode.OK,
                                ScriptRunResult("Unsupported script extension ${scriptFile.extension}", true)
                        )
                        return@post
                    }
                }

                ProcessBuilder(listOf(command,scriptFile.absolutePath, outputFolder.absolutePath))
                    .directory(scriptRoot)
                    .redirectOutput(ProcessBuilder.Redirect.PIPE)
                    .redirectErrorStream(true) // Merges stderr into stdout
                    .start().also { process -> 
                        launch {
                            process.inputStream.bufferedReader().run {
                                while(true) {
                                    readLine()?.let { line ->
                                        logger.trace(line) // realtime logging
                                        logs += "$line\n"
                                    } ?: break
                                }
                            }
                        }

                        process.waitFor(60, TimeUnit.MINUTES) // TODO: is this timeout OK/Needed?
                    }
            }.onSuccess { process -> // completed, with success or failure
                try { 
                    if(process.exitValue() != 0) {
                        error = true
                        logs += "Error: script returned non-zero value\n"
                    }
                    
                    if(resultFile.exists()) {
                        val type = object : TypeToken<Map<String, String>>() {}.type
                        outputs = gson.fromJson<Map<String, String>>(resultFile.readText(), type)
                        logger.trace(outputs.toString())
                    } else {
                        error = true
                        logs += "Error: output.json file not found\n"
                    }
                } catch (ex:IllegalThreadStateException) {
                    error = true
                    logs += "TIMEOUT occured\n"
                    process.destroy()
                }
                
            }.onFailure { ex ->
                logger.warn(ex.stackTraceToString())
                call.respond(HttpStatusCode.InternalServerError)
                return@post
            }
            
            // Format log output
            if(logs.isNotEmpty()) logs = "Full logs: $logs"
            call.respond(HttpStatusCode.OK, ScriptRunResult(logs, error, outputs))
        }
        else // Script not found
        {
            call.respond(HttpStatusCode.NotFound, ScriptRunResult("Script not found"))
            logger.warn("Error 404: Paths.runScript ${parameters.scriptPath} --> $scriptFile")
        }
    }

    get<Paths.scriptListGet> {
        val possible = mutableListOf<String>()
        val relPathIndex = scriptRoot.absolutePath.length + 1
        scriptRoot.walkTopDown().forEach { file ->
            if(file.extension.equals("yml")) {
                // Add the relative path, without the script root.
                possible.add(file.absolutePath.substring(relPathIndex))
            }
        }
        
        call.respond(possible)
    }
}

/**
 * 
 * @param {String} scriptFile 
 * @param {List} params 
 * @returns a folder for this invocation. Invoking with the same params will always give the same output folder.
 */
fun getOutputFolder(scriptPath: kotlin.String, body: kotlin.String?):File {
    // Unique to this script
    val scriptOutputFolder = File(ouputRoot, scriptPath.replace('.', '_'))

    // Unique to this script, with these parameters
    return File(scriptOutputFolder, 
        if(body == null) "no_params" else body.toMD5()
    )
}
