package org.geobon.pipeline

open class ConstantPipe(override val type: String, private val value: Any) : Pipe {
    companion object {
        fun create(type: String, stringValue: String): ConstantPipe {
            return when (type) {
                "int" -> ConstantPipe(type, stringValue.toInt())
                "float" -> ConstantPipe(type, stringValue.toFloat())
                else -> ConstantPipe(type, stringValue)
            }
        }
    }


    override suspend fun pull(): Any = value

    override fun dumpOutputFolders(allOutputs: MutableMap<String, String>) {
        // Not dumped
    }
}