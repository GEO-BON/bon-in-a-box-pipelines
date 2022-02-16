package org.geobon.script

import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.coroutineScope
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

class ScriptRun {
    var result:ScriptRunResult? = null

    private val scriptFile: File
    private val inputFileContent: String

    companion object {
        private val logger: Logger = LoggerFactory.getLogger(ScriptRun::class.java)
        private val gson = Gson()
    }

    constructor (scriptRelPath: String, inputFileContent:String) {
        this.scriptFile = File(scriptRoot, scriptRelPath)
        this.inputFileContent = inputFileContent
    }

    constructor (scriptFile: File, inputFileContent:String) {
        this.scriptFile = scriptFile
        this.inputFileContent = inputFileContent
    }

    suspend fun execute() {
        if(!scriptFile.exists()) {
            logger.warn("Error 404: Paths.runScript $scriptFile")
            result = ScriptRunResult("Script $scriptFile not found", true)
            return
        }

        // Create the output folder for this invocation
        val outputFolder = getOutputFolder(scriptFile.relativeTo(scriptRoot).path, inputFileContent)
        outputFolder.mkdirs()
        logger.trace("Paths.runScript outputting to $outputFolder")

        // Run the script
        var error = false
        var logs = ""
        var outputs:Map<String, String>? = null

        val resultFile = File(outputFolder, "output.json")
        runCatching {
            // Remove previous run result
            if(resultFile.delete()) {
                logger.trace("Previous results deleted")
            }

            // Create input.json
            val inputFile= File(outputFolder, "input.json")
            inputFile.writeText(inputFileContent)

            val command = when (scriptFile.extension) {
                "jl", "JL" -> "julia"
                "r", "R" -> "Rscript"
                else -> {
                    result = ScriptRunResult("Unsupported script extension ${scriptFile.extension}", true)
                    return
                }
            }

            ProcessBuilder(listOf(command,scriptFile.absolutePath, outputFolder.absolutePath))
                .directory(scriptRoot)
                .redirectOutput(ProcessBuilder.Redirect.PIPE)
                .redirectErrorStream(true) // Merges stderr into stdout
                .start().also { process ->
                    coroutineScope {
                        launch {
                            process.inputStream.bufferedReader().run {
                                while (true) {
                                    // TODO: Use delay() + BufferedReader.ready() to avoid blocking a thread.
                                    //  https://docs.oracle.com/javase/8/docs/api/java/io/BufferedReader.html#readLine--
                                    //  https://docs.oracle.com/javase/8/docs/api/java/io/BufferedReader.html#ready--
                                    readLine()?.let { line ->
                                        logger.trace(line) // realtime logging
                                        logs += "$line\n"
                                    } ?: break
                                }
                            }
                        }

                        // TODO: waitFor is blocking : https://docs.oracle.com/javase/8/docs/api/java/lang/Process.html#waitFor--
                        //  Use delay + isAlive() in a loop to avoid blocking a thread https://docs.oracle.com/javase/8/docs/api/java/lang/Process.html#isAlive--
                        withContext(Dispatchers.IO) {
                            process.waitFor(60, TimeUnit.MINUTES) // TODO: is this timeout OK/Needed?
                        }
                    }
                }
        }.onSuccess { process -> // completed, with success or failure
            try {
                if(process.exitValue() != 0) {
                    error = true
                    logs += "Error: script returned non-zero value\n"
                }

                if(resultFile.exists()) {
                    val type = object : TypeToken<Map<String, String>>() {}.type
                    val result = resultFile.readText()
                    logger.trace(result)
                    try {
                        outputs = gson.fromJson<Map<String, String>>(result, type)
                    } catch (e:Exception) {
                        error = true
                        logs += e.message + "\n"
                        logs += "Error: Malformed JSON file.\n"
                        logs += "Make sure complex results are saved in a separate file (csv, geojson, etc.).\n"
                        logs += "Content of output.json:\n"
                        logs += result
                    }
                } else {
                    error = true
                    logs += "Error: output.json file not found\n"
                }
            } catch (ex:IllegalThreadStateException) {
                error = true
                logs += "TIMEOUT occurred\n"
                process.destroy()
            }

        }.onFailure { ex ->
            logger.warn(ex.stackTraceToString())
            result = ScriptRunResult("An error occurred when running the script", true)
            return
        }

        // Format log output
        if(logs.isNotEmpty()) logs = "Full logs: $logs"
        result = ScriptRunResult(logs, error, outputs)
        return
    }

    /**
     *
     * @param {String} scriptFile
     * @param {List} params
     * @returns a folder for this invocation. Invoking with the same params will always give the same output folder.
     */
    private fun getOutputFolder(scriptPath: String, body: String?):File {
        // Unique to this script
        val scriptOutputFolder = File(outputRoot, scriptPath.replace('.', '_'))

        // Unique to this script, with these parameters
        return File(scriptOutputFolder,
            body?.toMD5() ?: "no_params"
        )
    }
}