package org.geobon.pipeline

import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import java.io.File

class AssignId(inputs: MutableMap<String, Pipe> = mutableMapOf()) :
    YMLStep(File(System.getenv("SCRIPT_LOCATION"),"pipeline/AssignId.yml").readText(), inputs = inputs) {

    var id:String? = null

    override fun validateInputsConfiguration(): String {
        val res =  super.validateInputsConfiguration()

        runBlocking {
            launch{
                id = inputs[IN_ID]?.pull().toString()
            }
        }

        return res
    }

    override suspend fun execute(resolvedInputs: Map<String, Any>): Map<String, Any> {
        return mapOf(OUT_IDENTIFIED_LAYER to JSONObject(mapOf(
            OUT_IDENTIFIED_LAYER_ID to resolvedInputs[IN_ID],
            OUT_IDENTIFIED_LAYER_LAYER to resolvedInputs[IN_LAYER]
        )))
    }

    companion object {
        // Inputs
        const val IN_ID = "id"
        const val IN_LAYER = "layer"

        // Outputs
        const val OUT_IDENTIFIED_LAYER = "identified_layer"
        const val OUT_IDENTIFIED_LAYER_ID = "id"
        const val OUT_IDENTIFIED_LAYER_LAYER = "layer"
    }
}