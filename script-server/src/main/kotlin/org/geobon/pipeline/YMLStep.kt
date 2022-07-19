package org.geobon.pipeline

import org.geobon.script.Description.INPUTS
import org.geobon.script.Description.OUTPUTS
import org.geobon.script.Description.TYPE
import org.geobon.script.Description.TYPE_OPTIONS
import org.yaml.snakeyaml.Yaml

abstract class YMLStep(
    yamlString: String = "",
    protected val yamlParsed: Map<String, Any> = Yaml().load(yamlString),
    inputs: MutableMap<String, Pipe> = mutableMapOf()
) : Step(inputs, readOutputs(yamlParsed)) {

    override fun validateInputsConfiguration(): String {
        val inputsFromYml = readInputs(yamlParsed)

        if (inputs.size != inputsFromYml.size) {
            return "Bad number of inputs.\n\tYAML spec: ${inputsFromYml.keys}\n\tReceived:  ${inputs.keys}\n"
        }

        // Validate presence and type of each input
        inputsFromYml.forEach { (inputKey, expectedType) ->
            inputs[inputKey]?.let {
                if (it.type != expectedType) {
                    return "Wrong type \"${it.type}\" for input \"$inputKey\", \"$expectedType\" expected.\n"
                }
            } ?: return "Missing key $inputKey\n\tYAML spec: ${inputsFromYml.keys}\n\tReceived:  ${inputs.keys}\n"
        }

        return ""
    }

    override fun validateInputsReceived(resolvedInputs:Map<String, Any>) {
        inputs.filter { (_, pipe) -> pipe.type == TYPE_OPTIONS }.forEach { (key, _) ->
            val options = readIODescription(INPUTS, key)?.get(TYPE_OPTIONS) as? List<*>
                ?: throw Exception("No options found for input parameter $key.")

            if(!options.contains(resolvedInputs[key])){
                throw Exception("Received value ${resolvedInputs[key]} not in options $options.")
            }
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

    companion object {
        /**
         * @return Map of input name to type
         */
        private fun readInputs(yamlParsed: Map<String, Any>): Map<String, String> {
            val inputs = mutableMapOf<String, String>()
            readIO(yamlParsed, INPUTS) { key, type ->
                inputs[key] = type
            }
            return inputs
        }

        /**
         * @return Map of output name to type
         */
        private fun readOutputs(yamlParsed: Map<String, Any>): Map<String, Output> {
            val outputs = mutableMapOf<String, Output>()
            readIO(yamlParsed, OUTPUTS) { key, type ->
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
                                println("$section description is not a map")
                            }
                        } ?: println("Invalid key")
                    }
                } else {
                    println("$section is not a map")
                }
            } ?: println("No $section map")
        }
    }
}


