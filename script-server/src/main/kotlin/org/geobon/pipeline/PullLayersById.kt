package org.geobon.pipeline

import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.File


class PullLayersById(inputs: MutableMap<String, Pipe> = mutableMapOf()) :
    YMLStep(File(System.getenv("SCRIPT_LOCATION"),"pipeline/PullLayersById.yml").readText(), inputs = inputs) {

    override suspend fun resolveInputs(): Map<String, Any> {
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
        var content:String = (resolvedInputs["with_ids"] ?: throw RuntimeException("Input with_ids is missing")) as String
        val identifiedLayers = resolvedInputs["identified_layers"] as? List<*> ?: throw RuntimeException("identified_layers is not an list")

        identifiedLayers.forEach { identifiedLayer ->
            if(identifiedLayer is JSONObject){
                content = content.replace(identifiedLayer.getString("id"), identifiedLayer.getString("layer"))
            } else {
                throw RuntimeException("identified_layers should contain json objects. Found ${identifiedLayer?.javaClass?.name}")
            }
        }

        return mapOf("with_layers" to content)
    }

}