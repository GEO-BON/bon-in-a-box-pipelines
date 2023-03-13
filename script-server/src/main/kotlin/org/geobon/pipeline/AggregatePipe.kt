package org.geobon.pipeline

import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch

class AggregatePipe(pipesToAggregate: List<Pipe>) : Pipe {
    override val type: String

    val pipes: MutableList<Pipe> = mutableListOf()

    init {
        if(pipesToAggregate.isEmpty())
            throw Exception("AggregatePipe requires a non-empty list")

        val candidateTypes = pipesToAggregate.mapTo(mutableSetOf()) { pipe ->
            if (pipe.type.endsWith("[]")) pipe.type else "${pipe.type}[]"
        }
        if (candidateTypes.size > 1)
            throw Exception("Multiple types received for single input: $candidateTypes")

        type = candidateTypes.first()

        pipesToAggregate.forEach { pipe ->
            if (pipe is AggregatePipe) {
                pipes.addAll(pipe.pipes) // merge lists
            } else {
                pipes.add(pipe)
            }
        }
    }

    override suspend fun pull(): Any {
        val resultList = mutableListOf<Any>()
        coroutineScope {
            pipes.forEach { pipe ->
                // This can happen in parallel coroutines
                launch {
                    val result = pipe.pull()
                    @Suppress("UNCHECKED_CAST")
                    (result as? Collection<Any>)?.let{
                        resultList.addAll(result)
                    } ?: resultList.add(result)
                }
            }
        }

        return resultList
    }

    override suspend fun pullIf(condition: (step: Step) -> Boolean): Any? {
        val resultList = mutableListOf<Any>()
        coroutineScope {
            pipes.forEach { pipe ->
                // This can happen in parallel coroutines
                launch {
                    val result = pipe.pullIf(condition)
                    if(result != null) {
                        @Suppress("UNCHECKED_CAST")
                        (result as? Collection<Any>)?.let{
                            resultList.addAll(result)
                        } ?: resultList.add(result)
                    }
                }
            }
        }

        return if(resultList.isEmpty()) null else resultList
    }

    override fun dumpOutputFolders(allOutputs: MutableMap<String, String>) {
        pipes.forEach { it.dumpOutputFolders(allOutputs) }
    }

    override fun validateGraph(): String {
        return pipes.fold("") { acc, pipe -> acc + pipe.validateGraph() }
    }
}