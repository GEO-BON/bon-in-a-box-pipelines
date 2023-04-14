package org.geobon.pipeline

interface PipelinePart {
    fun dumpOutputFolders(allOutputs: MutableMap<String, String>)
    fun validateGraph(): String
}