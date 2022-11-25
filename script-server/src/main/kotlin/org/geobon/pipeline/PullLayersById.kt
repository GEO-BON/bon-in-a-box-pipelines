package org.geobon.pipeline

import org.json.JSONObject
import java.io.File


class PullLayersById(inputs: MutableMap<String, Pipe> = mutableMapOf()) :
    YMLStep(File(System.getenv("SCRIPT_LOCATION"), "pipeline/PullLayersById.yml"), inputs = inputs) {

    override suspend fun resolveInputs(): Map<String, Any> {
        val resolvedInputs = mutableMapOf<String, Any>()

        // Only the ids present here will need to be pulled (!! is safe since input list was validated)
        val withIds = inputs[IN_WITH_IDS]!!.pull().toString()
        resolvedInputs[IN_WITH_IDS] = withIds

        // Pulling only if id found in above variable (!! is safe since input list was validated)
        resolvedInputs[IN_IDENTIFIED_LAYERS] = inputs[IN_IDENTIFIED_LAYERS]!!.pullIf { step -> 
            if(step is AssignId) {
                step.idForLayer?.let { withIds.contains(it) }
                    ?: false

            } else true
        } ?: throw RuntimeException("No id was found to replace in:\n$withIds")
   
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

        return mapOf(OUT_WITH_LAYERS to content).also{ record(it) }
    }

    companion object {
        // Inputs
        const val IN_IDENTIFIED_LAYERS = "identified_layers"
        const val IN_WITH_IDS = "with_ids"

        // Outputs
        const val OUT_WITH_LAYERS = "with_layers"
    }

}