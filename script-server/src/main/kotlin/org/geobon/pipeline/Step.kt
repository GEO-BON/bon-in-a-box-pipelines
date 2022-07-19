package org.geobon.pipeline

import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

abstract class Step(
    val inputs: MutableMap<String, Pipe> = mutableMapOf(),
    val outputs: Map<String, Output> = mapOf()
) {
    private var validated = false
    private var executed = false
    private val executeMutex = Mutex()

    init {
        outputs.values.forEach { it.step = this }
    }

    suspend fun execute() {
        executeMutex.withLock {
            if(executed)
                return // this has already been executed!

            val resolvedInputs = mutableMapOf<String, Any>()
            coroutineScope {
                inputs.forEach {
                    // This can happen in parallel coroutines
                    launch { resolvedInputs[it.key] = it.value.pull() }
                }
            }
            validateInputsReceived(resolvedInputs)

            val results = execute(resolvedInputs)
            results.forEach { (key, value) ->
                // Undocumented outputs will simply be discarded by the "?"
                outputs[key]?.let { output ->
                    output.value = value
                }
            }

            executed = true
        }
    }

    protected abstract suspend fun execute(resolvedInputs: Map<String, Any>): Map<String, Any>

    open fun validateGraph():String {
        if(validated)
            return "" // This avoids validating many times the same node in complex graphs

        var problems = validateInputsConfiguration()
        validated = true

        inputs.values.forEach { problems += it.validateGraph() }
        return problems
    }

    open fun validateInputsConfiguration(): String {
        // Not all steps need input validation.
        return ""
    }

    /**
     * Validates the received inputs and throws if something's wrong
     */
    open fun validateInputsReceived(resolvedInputs:Map<String, Any>) {
        // Not all steps need input validation.
    }

    open fun dumpOutputFolders(allOutputs: MutableMap<String, String>) {
        // Not all steps have output folders. Default implementation just forwards to other steps.
        inputs.values.forEach{it.dumpOutputFolders(allOutputs)}
    }
}