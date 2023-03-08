package org.geobon.pipeline

import org.geobon.utils.toMD5
import java.io.File

val outputRoot = File(System.getenv("OUTPUT_LOCATION"))

/**
 * @param id A unique string identifier representing a run of this step with these specific parameters.
 *           i.e. Calling the same script with the same param would result in the same ID.
 */
data class RunContext(val id: String) {
    constructor(descriptionFile: File, inputs: String?) : this(
        File(
            // Unique to this script
            descriptionFile.relativeTo(scriptRoot).path.removeSuffix(".yml"),
            // Unique to these params
            if (inputs.isNullOrEmpty()) "no_params" else inputs.toString().toMD5()
        ).path
    )

    val outputFolder
        get() = File(outputRoot, id)

    val inputFile: File
        get() = File(outputFolder, "input.json")

    val resultFile: File
        get() = File(outputFolder, "output.json")

    companion object {
        val scriptRoot
            get() = File(System.getenv("SCRIPT_LOCATION"))
    }
}