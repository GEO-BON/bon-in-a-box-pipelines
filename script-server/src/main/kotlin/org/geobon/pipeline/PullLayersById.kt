package org.geobon.pipeline

import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.File
import org.geobon.pipeline.AssignId


class PullLayersById(inputs: MutableMap<String, Pipe> = mutableMapOf()) :
    YMLStep(File(System.getenv("SCRIPT_LOCATION"), "pipeline/PullLayersById.yml").readText(), inputs = inputs) {

    override suspend fun resolveInputs(): Map<String, Any> {
        val identifiedLayers = inputs[IN_IDENTIFIED_LAYERS]

        val resolvedInputs = mutableMapOf<String, Any>()
        coroutineScope {
            inputs.forEach {
                // This can happen in parallel coroutines
                launch { resolvedInputs[it.key] = it.value.pull() }
            }
        }
        return resolvedInputs
    }

    override suspend fun execute(resolvedInputs: Map<String, Any>): Map<String, Any> {
        var content:String = (resolvedInputs[IN_WITH_IDS] ?: throw RuntimeException("Input with_ids is missing")) as String
        val identifiedLayers = resolvedInputs[IN_IDENTIFIED_LAYERS] as? List<*> ?: throw RuntimeException("identified_layers is not an list")

        identifiedLayers.forEach { identifiedLayer ->
            if(identifiedLayer is JSONObject){
                content = content.replace(
                    identifiedLayer.getString(AssignId.OUT_IDENTIFIED_LAYER_ID),
                    identifiedLayer.getString(AssignId.OUT_IDENTIFIED_LAYER_LAYER))
            } else {
                throw RuntimeException("identified_layers should contain json objects. Found ${identifiedLayer?.javaClass?.name}")
            }
        }

        return mapOf(OUT_WITH_LAYERS to content)
    }

    companion object {
        // Inputs
        val IN_IDENTIFIED_LAYERS = "identified_layers"
        val IN_WITH_IDS = "with_ids"


        // Outputs
        val OUT_WITH_LAYERS = "with_layers"
    }

}