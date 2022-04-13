package org.geobon.pipeline

open class ConstantPipe(override val type: String, private val value: Any) : Pipe {

    override suspend fun pull(): Any = value

    override fun dumpOutputFolders(allOutputs: MutableMap<String, String>) {
        // Not dumped
    }
}