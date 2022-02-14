package org.geobon.pipeline

class Input (override val type: String, private val source:Pipe) : Pipe {
    init {
        if(source.type != type) throw ExceptionInInitializerError("Input received wrong type")
    }

    override fun pull():String {return source.pull() }
}