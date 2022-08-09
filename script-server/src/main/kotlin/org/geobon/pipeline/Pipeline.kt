package org.geobon.pipeline

import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import org.json.JSONObject
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import java.io.File

val pipelinesRoot = File(System.getenv("PIPELINES_LOCATION"))

class Pipeline(descriptionFile: File) {
    constructor(relPath: String) : this(File(pipelinesRoot, relPath))

    companion object {
        private val logger: Logger = LoggerFactory.getLogger("Pipeline")
    }

    /**
     * All outputs that should be presented to the client as pipeline outputs.
     */
    private val pipelineOutputs = mutableListOf<Pipe>()
    fun getPipelineOutputs(): List<Pipe> = pipelineOutputs

    private val finalSteps: Set<Step>



    init {
        val steps = mutableMapOf<String, ScriptStep>()
        val constants = mutableMapOf<String, ConstantPipe>()
        val outputIds = mutableListOf<String>()

        // Load all nodes and classify them as steps, constants or pipeline outputs
        val jsonObject = JSONObject(descriptionFile.readText())
        jsonObject.getJSONArray(NODES_LIST).forEach { node ->
            if (node is JSONObject) {
                val id = node.getString(NODE__ID)
                when (node.getString(NODE__TYPE)) {
                    NODE__TYPE_SCRIPT -> {
                        steps[id] = ScriptStep(
                            node.getJSONObject(NODE__DATA)
                                .getString(NODE__DATA__FILE)
                                .replace('>', '/')
                        )
                    }
                    NODE__TYPE_CONSTANT -> {
                        val nodeData = node.getJSONObject(NODE__DATA)
                        val type = nodeData.getString(NODE__DATA__TYPE)

                        constants[id] = if(type.endsWith("[]")) {
                            val jsonArray = nodeData.getJSONArray(NODE__DATA__VALUE)

                            ConstantPipe(type,
                                when (type.removeSuffix("[]")) {
                                    "int" -> mutableListOf<Int>().apply {
                                        for (i in 0 until jsonArray.length()) add(jsonArray.optInt(i))
                                    }
                                    "float" -> mutableListOf<Float>().apply {
                                        for (i in 0 until jsonArray.length()) add(jsonArray.optFloat(i))
                                    }
                                    "boolean" -> mutableListOf<Boolean>().apply {
                                        for (i in 0 until jsonArray.length()) add(jsonArray.optBoolean(i))
                                    }
                                    // Everything else is read as text
                                    else -> mutableListOf<String>().apply {
                                        for (i in 0 until jsonArray.length()) add(jsonArray.optString(i))
                                    }
                                })
                        } else {
                            ConstantPipe(
                                type,
                                when (type) {
                                    "int" -> nodeData.getInt(NODE__DATA__VALUE)
                                    "float" -> nodeData.getFloat(NODE__DATA__VALUE)
                                    "boolean" -> nodeData.getBoolean(NODE__DATA__VALUE)
                                    // Everything else is read as text
                                    else -> nodeData.optString(NODE__DATA__VALUE)
                                }
                            )
                        }
                    }
                    NODE__TYPE_OUTPUT -> outputIds.add(id)
                    else -> logger.warn("Ignoring node type ${node.getString(NODE__TYPE)}")
                }
            } else {
                logger.warn("Unexpected object type under \"nodes\": ${node.javaClass}")
            }
        }

        // Link steps & constants by reading the edges, and populate the pipelineOutputs variable
        jsonObject.getJSONArray(EDGES_LIST).forEach { edge ->
            if(edge is JSONObject) {
                // Find the source pipe
                val sourceId = edge.getString(EDGE__SOURCE_ID)
                val sourcePipe = constants[sourceId] ?: steps[sourceId]?.let { sourceStep ->
                    val sourceOutput = edge.getString(EDGE__SOURCE_OUTPUT)
                    sourceStep.outputs[sourceOutput]
                        ?: throw Exception("Could not find output \"$sourceOutput\" in \"${sourceStep.yamlFile}.\"")
                } ?: throw Exception("Could not find step with ID: $sourceId")

                // Find the target and connect them
                val targetId = edge.getString(EDGE__TARGET_ID)
                if(outputIds.contains(targetId)) {
                    pipelineOutputs.add(sourcePipe)
                } else {
                    steps[targetId]?.let { step ->
                        val targetInput = edge.getString(EDGE__TARGET_INPUT)
                        step.inputs[targetInput] = step.inputs[targetInput].let {
                            if(it == null) sourcePipe else AggregatePipe(listOf(it, sourcePipe))
                        }
                    } ?: logger.warn("Dangling edge: could not find source $targetId")
                }

            } else {
                logger.warn("Unexpected object type under \"edges\": ${edge.javaClass}")
            }
        }


        // Call validate graph
        // (Only once per final step since stored in a set. There might be some duplication lower down the tree...)
        finalSteps = mutableSetOf<Step>().also { set ->
            pipelineOutputs.mapNotNullTo(set) { if (it is Output) it.step else null }
        }

        if(finalSteps.isEmpty())
            throw Exception("Pipeline has no designated output")

        finalSteps.forEach {
            val message = it.validateGraph()
            if(message != "") {
                throw Exception("Pipeline validation failed:\n$message")
            }
        }
    }

    fun dumpOutputFolders(allOutputs: MutableMap<String, String>) {
        finalSteps.forEach { it.dumpOutputFolders(allOutputs) }
    }

    suspend fun execute() {
        coroutineScope {
            finalSteps.forEach { launch { it.execute() } }
        }
    }

}