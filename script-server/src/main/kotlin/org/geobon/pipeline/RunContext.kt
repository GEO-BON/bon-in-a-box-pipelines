package org.geobon.pipeline

import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.google.gson.JsonParseException
import com.google.gson.stream.MalformedJsonException
import org.geobon.utils.toMD5
import java.io.File
import kotlin.math.floor

val outputRoot = File(System.getenv("OUTPUT_LOCATION"))

/**
 * @param runId A unique string identifier representing a run of this step with these specific parameters.
 *           i.e. Calling the same script with the same param would result in the same ID.
 */
data class RunContext(val runId: String, val inputs: String?) {
    constructor(descriptionFile: File, inputs: String?) : this(
        File(
            // Unique to this script
            descriptionFile.relativeTo(scriptRoot).path.removeSuffix(".yml"),
            // Unique to these params
            if (inputs.isNullOrEmpty()) "no_params" else inputs.toMD5()
        ).path,
        inputs
    )

    constructor(descriptionFile: File, inputMap: Map<String, Any?>) : this(
        descriptionFile,
        if (inputMap.isEmpty()) null else gson.toJson(inputMap)
    )

    val outputFolder
        get() = File(outputRoot, runId)

    val inputFile: File
        get() = File(outputFolder, "input.json")

    val resultFile: File
        get() = File(outputFolder, "output.json")

    companion object {
        val scriptRoot
            get() = File(System.getenv("SCRIPT_LOCATION"))

        val pipelineRoot
            get() = File(System.getenv("PIPELINES_LOCATION"))

        val gson: Gson = GsonBuilder()
            .serializeNulls()
            .setObjectToNumberStrategy { reader ->
                val value: String = reader.nextString()
                try {
                    val d = value.toDouble()
                    if ((d.isInfinite() || d.isNaN()) && !reader.isLenient) {
                        throw MalformedJsonException("JSON forbids NaN and infinities: " + d + "; at path " + reader.previousPath)
                    }

                    if (floor(d) == d) {
                        if (d > Integer.MAX_VALUE) d.toLong() else d.toInt()
                    } else {
                        d
                    }

                } catch (doubleE: NumberFormatException) {
                    throw JsonParseException("Cannot parse " + value + "; at path " + reader.previousPath, doubleE)
                }
            }
            .create()
    }
}