package org.geobon.pipeline

import org.yaml.snakeyaml.Yaml

open class YMLStep(
    yamlString: String = "",
    yamlParsed: Map<String, Any> = Yaml().load(yamlString),
    inputs: Map<String, Pipe> = mapOf()
) : Step(inputs, readOutputs(yamlParsed)) {

    init {
        val inputsFromYml = readInputs(yamlParsed)

        assert(inputs.size == inputsFromYml.size) {
            "Bad number of inputs\n\tYAML spec: ${inputsFromYml.keys}\n\tReceived:  ${inputs.keys}"
        }

        // Validate presence and type of each input
        inputsFromYml.forEach { (inputKey, expectedType) ->
            inputs[inputKey]?.let {
                assert(it.type == expectedType) { "Wrong type \"${it.type}\" for $inputKey, \"$expectedType\" expected." }
            } ?: throw AssertionError("Missing key $inputKey\n\tYAML spec: ${inputsFromYml.keys}\n\tReceived:  ${inputs.keys}")
        }

    }

    override fun execute(resolvedInputs: Map<String, String>): Map<String, String> {
        TODO("Not yet implemented")
    }

    companion object {
        private const val INPUTS = "inputs"
        private const val OUTPUTS = "outputs"
        private const val TYPE = "type"

        private fun readInputs(yamlParsed: Map<String, Any>): Map<String, String> {
            val inputs = mutableMapOf<String, String>()
            readIO(yamlParsed, INPUTS) { key, type ->
                inputs[key] = type
            }
            return inputs
        }

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
        private fun readIO(yamlParsed: Map<String, Any>, section:String, toExecute:(String, String) -> Unit) {
            yamlParsed[section]?.let {
                if(it is Map<*, *>) {
                    it.forEach { (key, description) ->
                        println("$key: $description")
                        key?.let {
                            //println("Key valid: $key")
                            if(description is Map<*, *>) {
                                //println("description is a map")
                                description[TYPE]?.let { type ->
                                    //println("Type valid: $type")
                                    toExecute(key.toString(), type.toString())
                                } ?: println("Invalid type")
                            } else {
                                println("Output description is not a map")
                            }
                        } ?: println("Invalid key")
                    }
                } else {
                    println("Outputs is not a map")
                }
            } ?: println("No output map")
        }
    }
}


