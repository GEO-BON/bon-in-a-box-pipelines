package org.geobon.pipeline

interface Pipe {
    val type:String
    fun pull():String
}