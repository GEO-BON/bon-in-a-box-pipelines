package org.geobon.pipeline

class ConstantPipe(override val type: String, private val value:Any) : Pipe {
    override suspend fun pull(): Any = value
}