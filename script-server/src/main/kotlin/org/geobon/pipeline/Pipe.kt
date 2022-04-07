package org.geobon.pipeline

interface Pipe {
    val type:String
    suspend fun pull():Any
    fun dumpOutputFolders(allOutputs: MutableMap<String, String>)

    fun validateGraph(): String {
        return ""
    }
}