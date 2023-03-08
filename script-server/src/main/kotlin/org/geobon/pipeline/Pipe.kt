package org.geobon.pipeline

interface Pipe {
    val type:String

    suspend fun pull(): Any

    suspend fun pullIf(condition: (step: Step) -> Boolean): Any?

    fun dumpOutputFolders(allOutputs: MutableMap<String, String>)

    fun validateGraph(): String

}