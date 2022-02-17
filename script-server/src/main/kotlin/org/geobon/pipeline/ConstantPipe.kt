package org.geobon.pipeline

class ConstantPipe(override val type: String, private val value:String) : Pipe {
    override suspend fun pull(): String = value
}