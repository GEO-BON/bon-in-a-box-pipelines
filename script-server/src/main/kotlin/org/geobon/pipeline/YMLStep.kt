package org.geobon.pipeline

import org.geobon.script.Description.INPUTS
import org.geobon.script.Description.OUTPUTS
import org.geobon.script.Description.TYPE
import org.yaml.snakeyaml.Yaml

abstract class YMLStep(
    yamlString: String = "",
    protected val yamlParsed: Map<String, Any> = Yaml().load(yamlString),
    inputs: MutableMap<String, Pipe> = mutableMapOf()
) : Step(inputs, readOutputs(yamlParsed)) {

    override fun validateStepInputs(): String {
        val inputsFromYml = readInputs(yamlParsed)

        if (inputs.size != inputsFromYml.size) {
            return "Bad number of inputs.\n\tYAML spec: ${inputsFromYml.keys}\n\tReceived:  ${inputs.keys}"
        }

        // Validate presence and type of each input
        inputsFromYml.forEach { (inputKey, expectedType) ->
            inputs[inputKey]?.let {
                if (it.type != expectedType) {
                    return "Wrong type \"${it.type}\" for input \"$inputKey\", \"$expectedType\" expected."
                }
            } ?: return "Missing key $inputKey\n\tYAML spec: ${inputsFromYml.keys}\n\tReceived:  ${inputs.keys}"
        }

        return ""
    }

    companion object {
        /**
         * @return Map of input name to type
         */
        private fun readInputs(yamlParsed: Map<String, Any>): Map<String, String> {
            val inputs = mutableMapOf<String, String>()
            readIO("inputs", yamlParsed, INPUTS) { key, type ->
                inputs[key] = type
            }
            return inputs
        }

        /**
         * @return Map of output name to type
         */
        private fun readOutputs(yamlParsed: Map<String, Any>): Map<String, Output> {
            val outputs = mutableMapOf<String, Output>()
            readIO("outputs", yamlParsed, OUTPUTS) { key, type ->
                outputs[key] = Output(type)
            }
            return outputs
        }

        /**
         * Since both Input and output look alike, function to read key and type is in common.
         */
        private fun readIO(
            label: String,
            yamlParsed: Map<String, Any>,
            section: String,
            toExecute: (String, String) -> Unit
        ) {
            yamlParsed[section]?.let {
                if (it is Map<*, *>) {
                    it.forEach { (key, description) ->
                        key?.let {
                            //println("Key valid: $key")
                            if (description is Map<*, *>) {
                                //println("description is a map")
                                description[TYPE]?.let { type ->
                                    //println("Type valid: $type")
                                    toExecute(key.toString(), type.toString())
                                } ?: println("Invalid type")
                            } else {
                                println("$label description is not a map")
                            }
                        } ?: println("Invalid key")
                    }
                } else {
                    println("$label is not a map")
                }
            } ?: println("No $label map")
        }
    }
}


