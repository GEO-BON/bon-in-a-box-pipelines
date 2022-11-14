package org.geobon.pipeline

open class ConstantPipe(override val type: String, private val value: Any) : Pipe {

    override suspend fun pull(): Any = value

    override suspend fun pullIf(condition: (step: Step) -> Boolean): Any? = value

    override fun dumpOutputFolders(allOutputs: MutableMap<String, String>) {
        // Not dumped
    }

    override fun validateGraph(): String {
        return ""
    }
}