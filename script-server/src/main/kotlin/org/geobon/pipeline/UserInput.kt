package org.geobon.pipeline

/**
 * Allows a user input to be fed to multiple steps.
 * JavaScript class equivalent: UserInputNode
 */
class UserInput(private val id: String, type: String) : Step(
    outputs = mapOf(id to Output(type))
) {
    override fun validateInputsConfiguration(): String {
        return if(inputs.containsKey(id)) "" else "User input missing for pipeline@$id"
    }

    override suspend fun execute(resolvedInputs: Map<String, Any>): Map<String, Any> {
        return mapOf(id to inputs[id]!!.pull())
    }
}
