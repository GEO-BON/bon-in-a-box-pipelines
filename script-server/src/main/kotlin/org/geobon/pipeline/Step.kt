package org.geobon.pipeline

import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch

abstract class Step(
    val inputs: MutableMap<String, Pipe> = mutableMapOf(),
    val outputs: Map<String, Output> = mapOf()
) {
    private var validated = false

    init {
        outputs.values.forEach { it.step = this }
    }

    suspend fun execute() {
        val resolvedInputs = mutableMapOf<String, Any>()
        coroutineScope {
            inputs.forEach {
                // This can happen in parallel coroutines
                launch { resolvedInputs[it.key] = it.value.pull() }
            }
        }

        val results = execute(resolvedInputs)

        results.forEach { (key, value) ->
            // Undocumented outputs will simply be discarded by the "?"
            outputs[key]?.let { output ->
                output.value = value
            }
        }
    }

    protected abstract suspend fun execute(resolvedInputs: Map<String, Any>): Map<String, Any>

    open fun validateGraph():String {
        if(validated)
            return "" // This avoids validating many times the same node in complex graphs

        var problems = validateStepInputs()
        validated = true

        inputs.values.forEach { problems += it.validateGraph() }
        return problems
    }

    open fun validateStepInputs(): String {
        return ""
    }

    open fun dumpOutputFolders(allOutputs: MutableMap<String, String>) {
        // Not all steps have output folders. Default implementation just forwards to other steps.
        inputs.values.forEach{it.dumpOutputFolders(allOutputs)}
    }
}