package org.geobon.pipeline

abstract class Step(
    protected val inputs: Map<String, Pipe> = mapOf(),
    val outputs: Map<String, Output> = mapOf()
) {
    init {
        outputs.values.forEach { it.step = this }
    }

    suspend fun execute() {
        val resolved = mutableMapOf<String, String>()
        inputs.forEach {
            resolved[it.key] = it.value.pull()
        }

        val results = execute(resolved)

        results.forEach { (key, value) ->
            // Undocumented outputs will simply be discarded by the "?"
            outputs[key]?.let { output ->
                output.value = value
            }
        }
    }

    abstract suspend fun execute(resolvedInputs: Map<String, String>): Map<String, String>

}