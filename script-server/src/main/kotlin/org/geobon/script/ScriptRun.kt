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
import java.util.SortedMap

val outputRoot = File(System.getenv("OUTPUT_LOCATION"))

class ScriptRun(private val scriptFile: File, private val inputFileContent: String?) {
    constructor(scriptFile: File, inputMap: SortedMap<String, Any>)
            : this(scriptFile, if (inputMap.isEmpty()) null else toJson(inputMap))

    lateinit var results: Map<String, Any>
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

    internal val outputFolder = File(outputRoot, id)
    private val inputFile = File(outputFolder, "input.json")
    internal val resultFile = File(outputFolder, "output.json")

    private val logger: Logger = LoggerFactory.getLogger(scriptFile.name)
    val logFile = File(outputFolder, "logs.txt")

    companion object {
        const val ERROR_KEY = "error"

        private val gson = Gson()

        fun toJson(src: Any): String = gson.toJson(src)

        val scriptRoot: File
            get() = File(System.getenv("SCRIPT_LOCATION"))
    }

    suspend fun execute() {
        results = loadFromCache()
            ?: runScript()
    }

    private fun loadFromCache(): Map<String, Any>? {
        // Looking for a cached result most recent than the script
        if (resultFile.exists()) {
            if (scriptFile.lastModified() < resultFile.lastModified()) {
                kotlin.runCatching {
                    gson.fromJson<Map<String, Any>>(
                        resultFile.readText().also { logger.trace("Cached outputs: $it") },
                        object : TypeToken<Map<String, Any>>() {}.type
                    )
                }.onSuccess { previousOutputs ->
                    // Use this result only if there was no error and inputs have not changed
                    if (previousOutputs[ERROR_KEY] == null
                        && inputsOlderThanCache()
                    ) {
                        logger.debug("Loading from cache")
                        return previousOutputs
                    }
                }.onFailure { e ->
                    logger.warn("Cache could not be reused: ${e.message}")
                }

            } else { // Script was updated, flush the whole cache for this script
                outputFolder.parentFile.deleteRecursively()
            }
        }

        return null
    }

    /**
     * @return true if all inputs are older than cached result
     */
    private fun inputsOlderThanCache(): Boolean {
        if (inputFile.exists()) {
            val cacheTime = resultFile.lastModified()
            kotlin.runCatching {
                gson.fromJson<Map<String, Any>>(
                    inputFile.readText().also { logger.trace("Cached inputs: $it") },
                    object : TypeToken<Map<String, Any>>() {}.type
                )
            }.onSuccess { inputs ->
                inputs.forEach { (_, value) ->
                    val stringValue = value.toString()
                    // We assume that all local paths start with / and that URLs won't.
                    if (stringValue.startsWith('/')) {
                        with(File(stringValue)) {
                            // check if missing or newer than cache
                            if (!exists() || cacheTime < lastModified()) {
                                return false
                            }
                        }
                    }
                }
            }.onFailure { e ->
                logger.warn("Error reading previous inputs: ${e.message}")
                return false // We could not validate inputs, discard the cache.
            }

            return true

        } else {
            return true // no input file => cache valid
        }
    }

    private suspend fun runScript(): Map<String, Any> {
        // TODO Wait if already running
        if (!scriptFile.exists()) {
            val message = "Script $scriptFile not found"
            logger.warn(message)
            return flagError(mapOf(ERROR_KEY to message), true)
        }

        // Run the script
        var error = false
        var outputs: Map<String, Any>? = null

        runCatching {
            withContext(Dispatchers.IO) {
                // If loading from cache didn't succeed, make sure we have a clean slate.
                outputFolder.deleteRecursively()

                // Create the output folder for this invocation
                outputFolder.mkdirs()
                logger.debug("Script run outputting to $outputFolder")

                // Script run pre-requisites
                logFile.createNewFile()
                inputFileContent?.let {
                    // Create input.json
                    inputFile.writeText(inputFileContent)
                }
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
            if (process.exitValue() != 0) {
                error = true
                log(logger::warn, "Error: script returned non-zero value")
            }

            if (resultFile.exists()) {
                val type = object : TypeToken<Map<String, Any>>() {}.type
                val result = resultFile.readText()
                try {
                    outputs = gson.fromJson<Map<String, Any>>(result, type)
                    logger.trace("Output: $result")
                } catch (e: Exception) {
                    error = true
                    log(
                        logger::warn, """
                        ${e.message}
                        Error: Malformed JSON file.
                        Make sure complex results are saved in a separate file (csv, geojson, etc.).
                        Contents of output.json:
                    """.trimIndent() + "\n$result"
                    )
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

    private fun log(func: (String?) -> Unit, line: String) {
        func(line) // realtime logging
        logFile.appendText("$line\n") // record
    }

    private fun flagError(results: Map<String, Any>, error: Boolean): Map<String, Any> {
        if (error || results.isEmpty()) {
            if (!results.containsKey(ERROR_KEY)) {
                val outputs = results.toMutableMap()
                outputs[ERROR_KEY] = "An error occurred. Check logs for details."

                // Rewrite output file with error
                resultFile.writeText(gson.toJson(outputs))

                return outputs
            }
        }
        return results
    }
}