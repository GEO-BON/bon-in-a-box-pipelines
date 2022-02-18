package org.geobon.pipeline

interface Pipe {
    val type:String
    suspend fun pull():Any
}