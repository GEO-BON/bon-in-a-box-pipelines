package org.geobon.pipeline

class Output(override val type:String) : Pipe {

    var step: Step? = null
    var value: Any? = null

    override suspend fun pull(): Any {
        if(value == null) {
            step?.execute()
                ?: throw RuntimeException("Output of type $type disconnected from any step when pulling")
        }
        return value ?: throw RuntimeException("Output of type $type has not been set by step $step")
    }

    override suspend fun pullIf(condition: (step: Step) -> Boolean): Any? {
        return step.let {
            if (it == null)
                throw RuntimeException("Output of type $type disconnected from any step when pulling conditionally")

            if(condition(it)) pull()
            else null
        }
    }

    override fun dumpOutputFolders(allOutputs: MutableMap<String, String>) {
        step?.dumpOutputFolders(allOutputs)
    }

    override fun validateGraph(): String {
        return step?.validateGraph()
            ?: "Output of type $type has no associated step\n"
    }

    override fun toString(): String {
        return "Output(type='$type', value=$value)"
    }

}
