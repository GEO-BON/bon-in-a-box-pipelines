package org.geobon.pipeline

class Output(override val type:String) : Pipe {

    var step: Step? = null
    var value:Any? = null

    override suspend fun pull(): Any {
        if(value == null) {
            step?.apply { execute() }
                ?: throw Exception("Output disconnected from any step")
        }
        return value ?: throw Exception("Output has not been set by step")
    }
}
