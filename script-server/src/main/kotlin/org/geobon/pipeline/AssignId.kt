package org.geobon.pipeline

import org.json.JSONObject
import java.io.File

class AssignId(inputs: MutableMap<String, Pipe> = mutableMapOf()) :
    YMLStep(File(System.getenv("SCRIPT_LOCATION"),"pipeline/AssignId.yml").readText(), inputs = inputs) {

    override suspend fun execute(resolvedInputs: Map<String, Any>): Map<String, Any> {
        val obj = JSONObject(mapOf(
            "id" to resolvedInputs["id"],
            "layer" to resolvedInputs["layer"]
        ))

        return mapOf("identified_layer" to obj)
    }
}