package org.geobon.pipeline

import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import org.geobon.pipeline.RunContext.Companion.pipelineRoot
import org.json.JSONObject
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import java.io.File

class RootPipeline(descriptionFile: File, inputsJSON: String? = null) :
    Pipeline(StepId("", ""), descriptionFile, inputsJSON) {

    constructor(relPath: String, inputsJSON: String? = null) : this(File(pipelineRoot, relPath), inputsJSON)

    init {
        linkInputs()

        val errors = validateGraph()
        if(errors.isNotEmpty()) {
            throw RuntimeException(errors)
        }
    }
}

open class Pipeline private constructor(
    override val id: StepId,
    pipelineJSON: JSONObject,
    private val descriptionFile: File,
    final override val inputs: MutableMap<String, Pipe>,
    final override val outputs: MutableMap<String, Output> = mutableMapOf()
) : IStep {

    private constructor(stepId: StepId, pipelineJSON:JSONObject, descriptionFile: File, inputsJSON: String? = null) : this(
        stepId,
        pipelineJSON,
        descriptionFile,
        inputsToConstants(inputsJSON, pipelineJSON),
    )

    constructor(stepId: StepId, descriptionFile: File, inputsJSON: String? = null) : this(
        stepId,
        JSONObject(descriptionFile.readText()),
        descriptionFile,
        inputsJSON
    )

    constructor(stepId: StepId, relPath: String, inputsJSON: String? = null) : this(
        stepId,
        File(pipelineRoot, relPath),
        inputsJSON
    )

    private val logger: Logger = LoggerFactory.getLogger(descriptionFile.nameWithoutExtension)

    fun getPipelineOutputs(): List<Pipe> = outputs.values.map { it }

    private val steps = mutableMapOf<String, IStep>()
    private val finalSteps: Set<Step>

    private var job: Job? = null

    init {
        val constants = mutableMapOf<String, ConstantPipe>()
        val outputIds = mutableListOf<String>()

        // Load all nodes and classify them as steps, constants or pipeline outputs
        pipelineJSON.getJSONArray(NODES_LIST).forEach { node ->
            if (node is JSONObject) {
                val nodeId = node.getString(NODE__ID)
                when (node.getString(NODE__TYPE)) {
                    NODE__TYPE_STEP -> {
                        val script = node.getJSONObject(NODE__DATA)
                            .getString(NODE__DATA__FILE)
                        val scriptFile = script.replace('>', '/')

                        val stepId = StepId(script, nodeId, id)
                        steps[nodeId] = when {
                            scriptFile.endsWith(".json") -> Pipeline(stepId, scriptFile)

                            // Instantiating kotlin "special steps".
                            // Not done with reflection on purpose, since this could allow someone to instantiate any class,
                            // resulting in a security breach.
                            scriptFile == "pipeline/AssignId.yml" -> AssignId(stepId)
                            scriptFile == "pipeline/PullLayersById.yml" -> PullLayersById(stepId)

                            // Regular script steps
                            else -> ScriptStep(scriptFile, stepId)
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

                        steps[nodeId] = UserInput(StepId("pipeline", nodeId, id), type)
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
                        ?: throw Exception("Could not find output \"$sourceOutput\" in \"${sourceStep}\".\n" +
                                "Available outputs: ${sourceStep.outputs}")
                } ?: throw Exception("Could not find step with ID: $sourceId")

                // Find the target and connect them
                val targetId = edge.getString(EDGE__TARGET_ID)
                if(outputIds.contains(targetId)) {
                    if(sourcePipe is Output) {
                        val step = steps[sourceId]
                        val outputId =
                            if (step is Pipeline) IOId(step.id, sourcePipe.getId())
                            else sourcePipe.getId()

                        outputs[outputId.toString()] = sourcePipe
                    } else {
                        throw Exception("output in json not of Output type: $targetId")
                    }
                } else {
                    steps[targetId]?.let { step ->
                        val targetInput = edge.getString(EDGE__TARGET_INPUT)
                        step.inputs[targetInput] = step.inputs[targetInput].let {
                            if(it == null) sourcePipe else AggregatePipe(listOf(it, sourcePipe))
                        }
                    } ?: logger.warn("Dangling edge: could not find target $targetId")
                }

            } else {
                logger.warn("Unexpected object type under \"edges\": ${edge.javaClass}")
            }
        }

        finalSteps = outputs.values.mapNotNullTo(mutableSetOf()) { it.step }
        if(finalSteps.isEmpty())
            throw Exception("Pipeline has no designated output")
    }

    /**
     * Links the inputs of the parent pipeline first, then all the nested pipelines.
     */
    protected fun linkInputs() {
        // Link inputs from the input file to the pipeline
        inputs.forEach { (key, pipe) ->
            val nodeId = getStepNodeId(key)
            val inputId = getStepInput(key) ?: Step.DEFAULT_IN // inputId uses default when step is a UserInput
            val step = steps[nodeId]
                ?: throw RuntimeException("Step id \"$nodeId\" does not exist in pipeline")

            step.inputs[inputId] = pipe
        }

        steps.forEach { entry ->
            (entry.value as? Pipeline)?.linkInputs()
        }
    }

    override fun dumpOutputFolders(allOutputs: MutableMap<String, String>) {
        // Not all steps have output folders. Default implementation just forwards to other steps.
        finalSteps.forEach { it.dumpOutputFolders(allOutputs) }
    }

    fun getLiveOutput(): Map<String, String> {
        return mutableMapOf<String, String>().also { dumpOutputFolders(it) }
    }

    /**
     * Pulls on the pipeline's outputs and returns the folder where we can find the results with cancelled,
     * failed and skipped steps annotated.
     * This function is meant to be called only on the root pipeline, in case of nested pipelines.
     *
     * @return the output folders for each step.
     * If the step was not executed, one of these special keywords will be used:
     * - skipped
     * - canceled
     */
    suspend fun pullFinalOutputs(): Map<String, String> {
        var cancelled = false
        var failure = false
        try {
            coroutineScope {
                job = launch {
                    execute()
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

    override fun validateGraph():String {
        // Pipeline is valid if all its steps are
        var problems = ""
        finalSteps.forEach { problems += it.validateGraph() }
        return problems
    }

    override suspend fun execute() {
        coroutineScope {
            finalSteps.forEach { launch { it.execute() } }
        } // exits when all final steps have their results
    }

    suspend fun stop() {
        job?.apply {
            cancel("Cancelled by user")
            join() // wait so the user receives response when really cancelled
        }
    }

    override fun toString(): String {
        return "Pipeline(descriptionFile=${descriptionFile.relativeTo(pipelineRoot)})"
    }

    companion object {
        private fun inputsToConstants(inputsJSON:String?, pipelineJSON: JSONObject) : MutableMap<String, Pipe> {
            if(inputsJSON == null)
                return mutableMapOf()

            val inputsParsed = JSONObject(inputsJSON)
            val constants = mutableMapOf<String, Pipe>()
            pipelineJSON.optJSONObject(INPUTS)?.let { inputsSpec ->
                inputsParsed.keySet().forEach { key ->
                    val inputSpec = inputsSpec.optJSONObject(key)
                        ?: throw RuntimeException("Input received \"$key\" is not listed in pipeline inputs. Listed inputs are ${inputsSpec.keySet()}")
                    val type = inputSpec.getString(INPUTS__TYPE)

                    constants[key] = createConstant(key, inputsParsed, type, key)
                }
            }

            return constants
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
    }

}
