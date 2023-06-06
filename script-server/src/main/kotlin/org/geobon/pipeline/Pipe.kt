package org.geobon.pipeline

interface Pipe : PipelinePart {
    val type:String

    suspend fun pull(): Any

    suspend fun pullIf(condition: (step: Step) -> Boolean): Any?
}