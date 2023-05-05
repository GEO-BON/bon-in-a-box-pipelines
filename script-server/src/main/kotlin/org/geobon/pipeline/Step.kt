package org.geobon.pipeline

import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * A step in a Pipeline
 * @param inputs A map of input id to input Pipe
 * @param outputs A map of output id to Output Pipe
 */
abstract class Step(
    override val id: StepId,
    override val inputs: MutableMap<String, Pipe> = mutableMapOf(),
    final override val outputs: Map<String, Output> = mapOf()
) : IStep {
    private var validated = false
    private var executed = false
    private val executeMutex = Mutex()

    init {
        outputs.values.forEach { it.step = this }
    }

    override suspend fun execute() {
        executeMutex.withLock {
            if(executed)
                return // this has already been executed! (success or failure)

            try {
                val resolvedInputs = resolveInputs()
                onInputsReceived(resolvedInputs)
                val results = execute(resolvedInputs)
                results.forEach { (key, value) ->
                    // Undocumented outputs will simply be discarded by the "?"
                    outputs[key]?.let { output ->
                        output.value = value
                    }
                }
            } finally {
                executed = true
            }
        }
    }

    open fun onInputsReceived(resolvedInputs: Map<String, Any>) {
        // Default nothing
    }

    protected abstract suspend fun execute(resolvedInputs: Map<String, Any>): Map<String, Any>

    protected open suspend fun resolveInputs(): Map<String, Any> {
        val resolvedInputs = mutableMapOf<String, Any>()
        coroutineScope {
            inputs.forEach {
                // This can happen in parallel coroutines
                launch { resolvedInputs[it.key] = it.value.pull() }
            }
        }
        return resolvedInputs
    }

    override fun validateGraph():String {
        if(validated)
            return "" // This avoids validating many times the same node in complex graphs

        var problems = validateInputsConfiguration()
        validated = true

        inputs.values.forEach { problems += it.validateGraph() }

        // Prepend id to better identify problem source
        return if(problems.isEmpty()) "" else "$id: $problems"
    }

    open fun validateInputsConfiguration(): String {
        // Not all steps need input validation.
        return ""
    }

    override fun dumpOutputFolders(allOutputs: MutableMap<String, String>) {
        // Not all steps have output folders. Default implementation just forwards to other steps.
        inputs.values.forEach{it.dumpOutputFolders(allOutputs)}
    }

    companion object {
        const val DEFAULT_IN = "defaultInput"
        const val DEFAULT_OUT = "defaultOutput"
    }
}