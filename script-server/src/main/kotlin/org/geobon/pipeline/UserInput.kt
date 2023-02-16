package org.geobon.pipeline

/**
 * Allows a user input to be fed to multiple steps.
 * JavaScript class equivalent: UserInputNode
 */
class UserInput(private val id: String, type: String) : Step(
    outputs = mapOf(DEFAULT_OUT to Output(type))
) {
    override fun validateInputsConfiguration(): String {
        return if(inputs.containsKey(DEFAULT_IN)) "" else "User input missing for pipeline@$id"
    }

    override suspend fun execute(resolvedInputs: Map<String, Any>): Map<String, Any> {
        return mapOf(DEFAULT_OUT to inputs[DEFAULT_IN]!!.pull())
    }
}
