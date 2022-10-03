package org.geobon.pipeline

import kotlinx.coroutines.launch
import kotlinx.coroutines.supervisorScope

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
        supervisorScope {
            pipes.forEach {
                // This can happen in parallel coroutines
                launch {
                    val result = it.pull()
                    @Suppress("UNCHECKED_CAST")
                    (result as? Collection<Any>)?.let{
                        resultList.addAll(it)
                    } ?: resultList.add(result)
                }
            }
        }

        return resultList
    }

    override fun dumpOutputFolders(allOutputs: MutableMap<String, String>) {
        pipes.forEach { it.dumpOutputFolders(allOutputs) }
    }
}