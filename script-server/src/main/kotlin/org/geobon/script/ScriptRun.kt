package org.geobon.script

import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.openapitools.server.models.ScriptRunResult
import org.openapitools.server.utils.toMD5
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import java.io.File
import java.util.concurrent.TimeUnit

val scriptRoot = File(System.getenv("SCRIPT_LOCATION"))
val outputRoot = File(System.getenv("OUTPUT_LOCATION"))

class ScriptRun (private val scriptFile: File, private val inputFileContent:String?) {
    lateinit var result:ScriptRunResult
        private set

    /**
     * A unique string identifier representing a run of this script with these specific parameters.
     * i.e. Calling the same script with the same param would result in the same ID.
     */
    val id = File(
        // Unique to this script
        scriptFile.relativeTo(scriptRoot).path,
        // Unique to these params
        inputFileContent?.toMD5() ?: "no_params"
    ).path.replace('.', '_')

    companion object {
        const val ERROR_KEY = "error"

        private val logger: Logger = LoggerFactory.getLogger("Script")
        private val gson = Gson()

        fun toJson(src: Any): String = gson.toJson(src)
    }

    suspend fun execute() {
        result = getResult()
    }

    private suspend fun getResult():ScriptRunResult {
        if(!scriptFile.exists()) {
            logger.warn("Error 404: Paths.runScript $scriptFile")
            return flagError(ScriptRunResult("Script $scriptFile not found"), true)
        }

        // Create the output folder for this invocation
        val outputFolder = File(outputRoot, id)
        outputFolder.mkdirs()
        logger.trace("Paths.runScript outputting to $outputFolder")

        // Run the script
        var error = false
        var logs = ""
        var outputs:Map<String, Any>? = null

        val resultFile = File(outputFolder, "output.json")
        runCatching {
            // Remove previous run result
            if(resultFile.delete()) {
                logger.trace("Previous results deleted")
            }

            inputFileContent?.let {
                // Create input.json
                val inputFile = File(outputFolder, "input.json")
                inputFile.writeText(inputFileContent)
            }

            val command = when (scriptFile.extension) {
                "jl", "JL" -> "julia"
                "r", "R" -> "Rscript"
                "sh" -> "sh"
                "py", "PY" -> "python3"
                else -> "Unsupported script extension ${scriptFile.extension}".let {
                    logger.warn(it)
                    return flagError(ScriptRunResult(it), true)
                }
            }

            ProcessBuilder(listOf(command, scriptFile.absolutePath, outputFolder.absolutePath))
                .directory(scriptRoot)
                .redirectOutput(ProcessBuilder.Redirect.PIPE)
                .redirectErrorStream(true) // Merges stderr into stdout
                .start().also { process ->
                    withContext(Dispatchers.IO) { // More info on this context switching : https://elizarov.medium.com/blocking-threads-suspending-coroutines-d33e11bf4761
                        launch {
                            process.inputStream.bufferedReader().run {
                                while (true) { // Breaks when readLine returns null
                                    readLine()?.let { line ->
                                        logger.trace(line) // realtime logging
                                        logs += "$line\n" // record
                                    } ?: break
                                }
                            }
                        }

                        process.waitFor(60, TimeUnit.MINUTES) // TODO: is this timeout OK/Needed?
                        if (process.isAlive) {
                            logs += "TIMEOUT occurred after 1h".also { logger.warn(it) } + "\n"
                            process.destroy()
                        }
                    }
                }
        }.onSuccess { process -> // completed, with success or failure
            if(process.exitValue() != 0) {
                error = true
                logs += "Error: script returned non-zero value".also { logger.warn(it) } + "\n"
            }

            if(resultFile.exists()) {
                val type = object : TypeToken<Map<String, Any>>() {}.type
                val result = resultFile.readText()
                try {
                    outputs = gson.fromJson<Map<String, Any>>(result, type)
                    logger.trace(result)
                } catch (e:Exception) {
                    error = true
                    logs +=  ("""
                        ${e.message}
                        Error: Malformed JSON file.
                        Make sure complex results are saved in a separate file (csv, geojson, etc.).
                        Contents of output.json:
                    """.trimIndent() + "\n$result").also { logger.warn(it) }
                }
            } else {
                error = true
                logs += "Error: output.json file not found".also { logger.warn(it) } + "\n"
            }

        }.onFailure { ex ->
            logger.warn(ex.stackTraceToString())
            logs += "An error occurred when running the script: ${ex.message}"
            return flagError(ScriptRunResult(logs), true)
        }

        // Format log output
        if(logs.isNotEmpty()) logs = "Full logs: $logs"
        return flagError(ScriptRunResult(logs, outputs ?: mapOf()), error)
    }

    private fun flagError(result: ScriptRunResult, error:Boolean) : ScriptRunResult {
        if(error) {
            if(!result.files.containsKey(ERROR_KEY)) {
                val outputs = result.files.toMutableMap()
                outputs[ERROR_KEY] = "An error occurred. Check logs for details."

                // TODO: rewrite the output.json file

                return ScriptRunResult(result.logs, outputs)
            }
        }
        return result
    }
}