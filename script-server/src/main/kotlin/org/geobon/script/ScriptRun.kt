package org.geobon.script

import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.openapitools.server.utils.toMD5
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import java.io.File
import java.util.concurrent.TimeUnit

val scriptRoot = File(System.getenv("SCRIPT_LOCATION"))
val outputRoot = File(System.getenv("OUTPUT_LOCATION"))

class ScriptRun (private val scriptFile: File, private val inputFileContent:String?) {
    lateinit var results:Map<String, Any>
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

    private val outputFolder = File(outputRoot, id)
    private val resultFile = File(outputFolder, "output.json")
    val logFile = File(outputFolder, "logs.txt")

    companion object {
        const val ERROR_KEY = "error"

        private val logger: Logger = LoggerFactory.getLogger("Script")
        private val gson = Gson()

        fun toJson(src: Any): String = gson.toJson(src)
    }

    suspend fun execute() {
        results = getResult()
    }

    private suspend fun getResult():Map<String, Any> {
        if(!scriptFile.exists()) {
            log(logger::warn, "Script $scriptFile not found")
            return flagError(mapOf(), true)
        }

        // Create the output folder for this invocation
        outputFolder.mkdirs()
        logger.debug("Script run outputting to $outputFolder")

        // Run the script
        var error = false
        var outputs:Map<String, Any>? = null

        runCatching {
            // Remove previous run result
            // TODO this is temp until we use the cache.
            if(resultFile.delete()) logger.trace("Previous results deleted")
            if(logFile.delete()) logger.trace("Previous results deleted")
            withContext(Dispatchers.IO) {
                logFile.createNewFile()
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
                else -> {
                    log(logger::warn, "Unsupported script extension ${scriptFile.extension}")
                    return flagError(mapOf(), true)
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
                                    readLine()?.let { log(logger::trace, it) }
                                        ?: break
                                }
                            }
                        }

                        process.waitFor(60, TimeUnit.MINUTES) // TODO: is this timeout OK/Needed?
                        if (process.isAlive) {
                            log(logger::warn, "TIMEOUT occurred after 1h")
                            process.destroy()
                        }
                    }
                }
        }.onSuccess { process -> // completed, with success or failure
            if(process.exitValue() != 0) {
                error = true
                log(logger::warn, "Error: script returned non-zero value")
            }

            if(resultFile.exists()) {
                val type = object : TypeToken<Map<String, Any>>() {}.type
                val result = resultFile.readText()
                try {
                    outputs = gson.fromJson<Map<String, Any>>(result, type)
                    logger.trace(result)
                } catch (e:Exception) {
                    error = true
                    log(logger::warn, """
                        ${e.message}
                        Error: Malformed JSON file.
                        Make sure complex results are saved in a separate file (csv, geojson, etc.).
                        Contents of output.json:
                    """.trimIndent() + "\n$result")
                }
            } else {
                error = true
                log(logger::warn, "Error: output.json file not found")
            }

        }.onFailure { ex ->
            log(logger::warn, "An error occurred when running the script: ${ex.message}")
            logger.warn(ex.stackTraceToString())
            error = true
        }

        // Format log output
        return flagError(outputs ?: mapOf(), error)
    }

    private fun log(func: (String?)->Unit, line: String) {
        func(line) // realtime logging
        logFile.appendText("$line\n") // record
    }

    private fun flagError(results: Map<String, Any>, error:Boolean) : Map<String, Any> {
        if(error || results.isEmpty()) {
            if(!results.containsKey(ERROR_KEY)) {
                val outputs = results.toMutableMap()
                outputs[ERROR_KEY] = "An error occurred. Check logs for details."

                // Rewrite output file with error
                resultFile.writeText(gson.toJson(outputs))

                return results
            }
        }
        return results
    }
}