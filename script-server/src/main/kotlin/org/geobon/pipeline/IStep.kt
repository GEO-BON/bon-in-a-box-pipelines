package org.geobon.pipeline

interface IStep : PipelinePart {
    val id: String
    val inputs: Map<String, Pipe>
    val outputs: Map<String, Output>
    suspend fun execute()
}