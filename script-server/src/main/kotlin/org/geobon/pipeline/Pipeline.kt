package org.geobon.pipeline

import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import org.json.JSONObject
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import java.io.File

class Pipeline(descriptionFile: File, inputs: String? = null) {
    constructor(relPath: String, inputs: String? = null) : this(
        File(System.getenv("PIPELINES_LOCATION"), relPath),
        inputs
    )

    private val logger: Logger = LoggerFactory.getLogger(descriptionFile.nameWithoutExtension)

    /**
     * All outputs that should be presented to the client as pipeline outputs.
     */
    private val pipelineOutputs = mutableListOf<Pipe>()
    fun getPipelineOutputs(): List<Pipe> = pipelineOutputs

    private val finalSteps: Set<Step>

    var job: Job? = null

    init {
        val steps = mutableMapOf<String, Step>()
        val constants = mutableMapOf<String, ConstantPipe>()
        val outputIds = mutableListOf<String>()

        // Load all nodes and classify them as steps, constants or pipeline outputs
        val pipelineJSON = JSONObject(descriptionFile.readText())
        pipelineJSON.getJSONArray(NODES_LIST).forEach { node ->
            if (node is JSONObject) {
                val nodeId = node.getString(NODE__ID)
                when (node.getString(NODE__TYPE)) {
                    NODE__TYPE_SCRIPT -> {
                        val scriptFile = node.getJSONObject(NODE__DATA)
                            .getString(NODE__DATA__FILE)
                            .replace('>', '/')

                        steps[nodeId] = when (scriptFile) {
                            // Instantiating kotlin "special steps".
                            // Not done with reflection on purpose, since this could allow someone to instantiate any class,
                            // resulting in a security breach.
                            "pipeline/AssignId.yml" -> AssignId()
                            "pipeline/PullLayersById.yml" -> PullLayersById()

                            // Regular script steps
                            else -> ScriptStep(scriptFile, nodeId)
                        }
                    }

                    NODE__TYPE_CONSTANT -> {
                        val nodeData = node.getJSONObject(NODE__DATA)
                        val type = nodeData.getString(NODE__DATA__TYPE)
                        constants[nodeId] = createConstant(nodeId, nodeData, type, NODE__DATA__VALUE)
                    }

                    NODE__TYPE_USER_INPUT -> {
                        val nodeData = node.getJSONObject(NODE__DATA)
                        val type = nodeData.getString(NODE__DATA__TYPE)

                        steps[nodeId] = UserInput(nodeId, type)
                    }

                    NODE__TYPE_OUTPUT -> outputIds.add(nodeId)
                    else -> logger.warn("Ignoring node type ${node.getString(NODE__TYPE)}")
                }
            } else {
                logger.warn("Unexpected object type under \"nodes\": ${node.javaClass}")
            }
        }

        // Link steps & constants by reading the edges, and populate the pipelineOutputs variable
        pipelineJSON.getJSONArray(EDGES_LIST).forEach { edge ->
            if(edge is JSONObject) {
                // Find the source pipe
                val sourceId = edge.getString(EDGE__SOURCE_ID)
                val sourcePipe = constants[sourceId] ?: steps[sourceId]?.let { sourceStep ->
                    val sourceOutput = edge.optString(EDGE__SOURCE_OUTPUT, Step.DEFAULT_OUT)
                    sourceStep.outputs[sourceOutput]
                        ?: throw Exception("Could not find output \"$sourceOutput\" in \"${sourceStep}.\"")
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

        // Link inputs from the input file to the pipeline
        inputs?.let {
            val inputsJSON = JSONObject(inputs)
            pipelineJSON.optJSONObject(INPUTS)?.let { inputsSpec ->
                val regex = """([.>\w]+)@(\d+)(\.(\w+))?""".toRegex()
                inputsJSON.keySet().forEach { key ->
                    val inputSpec = inputsSpec.optJSONObject(key)
                        ?: throw RuntimeException("Input received \"$key\" is not listed in pipeline inputs. Listed inputs are ${inputsSpec.keySet()}")
                    val type = inputSpec.getString(INPUTS__TYPE)

                    val groups = regex.matchEntire(key)?.groups
                        ?: throw RuntimeException("Input id \"$key\" is malformed")
                    //val path = groups[1]!!.value
                    val stepId = groups[2]!!.value
                    val inputId = groups[4]?.value ?: Step.DEFAULT_IN // inputId = default when step is a UserInput

                    val step = steps[stepId]
                        ?: throw RuntimeException("Step id \"$stepId\" does not exist in pipeline")

                    step.inputs[inputId] = createConstant(key, inputsJSON, type, key)
                }
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


    private fun createConstant(idForUser: String, obj: JSONObject, type:String, valueProperty:String): ConstantPipe {

        return if (type.endsWith("[]")) {
            val jsonArray = try {
                obj.getJSONArray(valueProperty)
            } catch (e: Exception) {
                throw RuntimeException("Constant array #$idForUser has no value in JSON file.")
            }

            ConstantPipe(type,
                when (type.removeSuffix("[]")) {
                    "int" -> mutableListOf<Int>().apply {
                        for (i in 0 until jsonArray.length()) add(jsonArray.optInt(i))
                    }
                    "float" -> mutableListOf<Float>().apply {
                        for (i in 0 until jsonArray.length()) {
                            val float = jsonArray.optFloat(i)
                            if (!float.isNaN()) {
                                add(float)
                            }
                        }
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
            try {
                ConstantPipe(
                    type,
                    when (type) {
                        "int" -> obj.getInt(valueProperty)
                        "float" -> obj.getFloat(valueProperty)
                        "boolean" -> obj.getBoolean(valueProperty)
                        // Everything else is read as text
                        else -> obj.getString(valueProperty)
                    }
                )
            } catch (e: Exception) {
                e.printStackTrace()
                throw RuntimeException("Constant #$idForUser has no value in JSON file.")
            }
        }
    }

    fun dumpOutputFolders(allOutputs: MutableMap<String, String>) {
        finalSteps.forEach { it.dumpOutputFolders(allOutputs) }
    }

    fun getLiveOutput(): Map<String, String> {
        return mutableMapOf<String, String>().also { dumpOutputFolders(it) }
    }

    /**
     * @return the output folders for each step.
     * If the step was not executed, one of these special keywords will be used:
     * - skipped
     * - canceled
     */
    suspend fun execute(): Map<String, String> {
        var cancelled = false
        var failure = false
        try {
            coroutineScope {
                job = launch {
                    coroutineScope {
                        finalSteps.forEach { launch { it.execute() } }
                    } // exits when all final steps have their results
                }
            }

            job?.apply { cancelled = isCancelled }
        } catch (ex: RuntimeException) {
            logger.debug("In execute \"${ex.message ?: ex.stackTraceToString()}\"")
            if (!cancelled) failure = true
        } catch (ex: Exception) {
            logger.error(ex.stackTraceToString())
        } finally {
            job = null
        }

        return getLiveOutput().mapValues { (_, value) ->
            when {
                value.isNotEmpty() -> value
                cancelled -> "cancelled"
                failure -> "aborted"
                else -> "skipped"
            }
        }
    }

    suspend fun stop() {
        job?.apply {
            cancel("Cancelled by user")
            join() // wait so the user receives response when really cancelled
        }
    }

}
