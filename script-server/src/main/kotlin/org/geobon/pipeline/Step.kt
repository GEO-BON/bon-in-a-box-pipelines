package org.geobon.pipeline

import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch

abstract class Step(
    protected val inputs: Map<String, Pipe> = mapOf(),
    val outputs: Map<String, Output> = mapOf()
) {
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

    abstract suspend fun execute(resolvedInputs: Map<String, Any>): Map<String, Any>

    open fun validateGraph():String {
        var problems = validateStepInputs()
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