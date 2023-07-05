package org.geobon.pipeline

import org.geobon.script.Description.INPUTS
import org.geobon.script.Description.OUTPUTS
import org.geobon.script.Description.TYPE
import org.geobon.script.Description.TYPE_OPTIONS
import org.geobon.script.ScriptRun
import org.json.JSONObject
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.yaml.snakeyaml.Yaml
import java.io.File


abstract class YMLStep(
    protected val yamlFile: File,
    stepId:StepId,
    inputs: MutableMap<String, Pipe> = mutableMapOf(),
    private val logger: Logger = LoggerFactory.getLogger(yamlFile.name),
    protected val yamlParsed: Map<String, Any> = Yaml().load(yamlFile.readText())
) : Step(stepId, inputs, readOutputs(yamlParsed, logger)) {

    /**
     * Context becomes set in validateInputsReceived(), once the invocation inputs are known.
     */
    protected var context:RunContext? = null

    override fun validateInputsConfiguration(): String {
        val inputsFromYml = readInputs(yamlParsed, logger)

        if (inputs.size != inputsFromYml.size) {
            return "Bad number of inputs." +
                    "\n\tYAML spec: ${inputsFromYml.keys}" +
                    "\n\tReceived:  ${inputs.keys}" +
                    "\n\tExtra keys: ${inputs.mapNotNull { if (inputsFromYml.containsKey(it.key)) null else it.key }}" +
                    "\n\tMissing keys: ${inputsFromYml.mapNotNull { if (inputs.containsKey(it.key)) null else it.key }}\n"
        }

        // Validate presence and type of each input
        var errorMessages = ""
        inputsFromYml.forEach { (inputKey, expectedType) ->
            errorMessages += inputs[inputKey]?.let {
                if (it.type == expectedType) ""
                // Check for convertible types (currently only int to float, use a map/when if more conversions are possible)
                else when {
                    // int to float accepted
                    it.type == "int" && expectedType == "float" -> ""

                    // Non-array to single-element array accepted
                    expectedType.endsWith("[]") && it.type == expectedType.dropLast(2) -> {
                        inputs[inputKey] = AggregatePipe(listOf(it))
                        return@let ""
                    }

                    // Everything else refused
                    else -> "Wrong type \"${it.type}\" for input \"$inputKey\", \"$expectedType\" expected.\n"
                }
            } ?: "Missing key $inputKey\n\tYAML spec: ${inputsFromYml.keys}\n\tReceived:  ${inputs.keys}\n"
        }

        return errorMessages
    }

    override fun onInputsReceived(resolvedInputs: Map<String, Any?>) {
        // Now that we know the inputs are valid, record the id
        context = RunContext(yamlFile, resolvedInputs.toString())

        try { // Validation
            inputs.filter { (_, pipe) -> pipe.type == TYPE_OPTIONS }.forEach { (key, _) ->
                val options = readIODescription(INPUTS, key)?.get(TYPE_OPTIONS) as? List<*>
                    ?: throw RuntimeException("$yamlFile: No options found for input parameter $key.")

                if (!options.contains(resolvedInputs[key])) {
                    throw RuntimeException("$yamlFile: Received value ${resolvedInputs[key]} not in options $options.")
                }
            }
        } catch (e:RuntimeException) {
            record(mapOf(ScriptRun.ERROR_KEY to (e.message ?: e.toString())))
            throw e
        }
    }

    protected fun record(results: Map<String, Any>) {
        context?.apply {
            if(outputFolder.exists())
                outputFolder.deleteRecursively()

            outputFolder.mkdirs()
            resultFile.writeText(JSONObject(results).toString(2))
        }
    }

    private fun readIODescription(section:String, searchedKey:String) : Map<*,*>? {
        (yamlParsed[section] as? Map<*, *>)?.forEach { (key, description) ->
            if(key == searchedKey) {
                return description as? Map<*, *>
            }
        } ?: println("$section is not a valid map")

        return null
    }

    /**
     * @param allOutputs Map of Step identifier to output folder.
     */
    override fun dumpOutputFolders(allOutputs: MutableMap<String, String>) {
        val previousValue = allOutputs.put(id.toBreadcrumbs(), context?.runId ?: "")

        // Pass it on only if not already been there (avoids duplication for more complex graphs)
        if (previousValue == null) {
            super.dumpOutputFolders(allOutputs)
        }
    }

    companion object {

        /**
         * @return Map of input name to type
         */
        private fun readInputs(yamlParsed: Map<String, Any>, logger: Logger): Map<String, String> {
            val inputs = mutableMapOf<String, String>()
            readIO(yamlParsed, INPUTS, logger) { key, type ->
                inputs[key] = type
            }
            return inputs
        }

        /**
         * @return Map of output name to type
         */
        private fun readOutputs(yamlParsed: Map<String, Any>, logger: Logger): Map<String, Output> {
            val outputs = mutableMapOf<String, Output>()
            readIO(yamlParsed, OUTPUTS, logger) { key, type ->
                outputs[key] = Output(type)
            }
            return outputs
        }

        /**
         * Since both Input and output look alike, function to read key and type is in common.
         */
        private fun readIO(
            yamlParsed: Map<String, Any>,
            section: String,
            logger: Logger,
            toExecute: (String, String) -> Unit,
        ) {
            yamlParsed[section]?.let {
                if (it is Map<*, *>) {
                    it.forEach { (key, description) ->
                        key?.let {
                            if (description is Map<*, *>) {
                                description[TYPE]?.let { type ->
                                    toExecute(key.toString(), type.toString())
                                } ?: logger.error("Invalid type")
                            } else {
                                logger.error("$section description is not a map")
                            }
                        } ?: logger.error("Invalid key")
                    }
                } else {
                    logger.error("$section is not a map")
                }
            } ?: logger.trace("No $section map")
        }
    }
}


