package org.geobon.pipeline

import org.json.JSONObject
import java.io.File

class AssignId(inputs: MutableMap<String, Pipe> = mutableMapOf()) :
    YMLStep(File(System.getenv("SCRIPT_LOCATION"),"pipeline/AssignId.yml").readText(), inputs = inputs) {

    override suspend fun execute(resolvedInputs: Map<String, Any>): Map<String, Any> {
        return mapOf(OUT_IDENTIFIED_LAYER to JSONObject(mapOf(
            OUT_IDENTIFIED_LAYER_ID to resolvedInputs[IN_ID],
            OUT_IDENTIFIED_LAYER_LAYER to resolvedInputs[IN_LAYER]
        )))
    }

    companion object {
        // Inputs
        val IN_ID = "id"
        val IN_LAYER = "layer"

        // Outputs
        val OUT_IDENTIFIED_LAYER = "identified_layer"
        val OUT_IDENTIFIED_LAYER_ID = "id"
        val OUT_IDENTIFIED_LAYER_LAYER = "layer"
    }
}