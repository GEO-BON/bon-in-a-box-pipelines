package org.geobon.pipeline

class Output(override val type:String) : Pipe {

    var step: Step? = null
    var value: Any? = null

    override suspend fun pull(): Any {
        if(value == null) {
            step?.apply { execute() }
                ?: throw RuntimeException("Output disconnected from any step")
        }
        return value ?: throw RuntimeException("Output has not been set by step")
    }

    override fun dumpOutputFolders(allOutputs: MutableMap<String, String>) {
        step?.dumpOutputFolders(allOutputs)
    }

    override fun validateGraph(): String {
        return step?.validateGraph()
            ?: "Output has no associated step\n"
    }

    override fun toString(): String {
        return "Output(type='$type', value=$value)"
    }

}
