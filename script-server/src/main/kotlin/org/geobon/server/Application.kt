package org.geobon.server

import io.ktor.server.application.*
import io.ktor.server.routing.*
import org.geobon.server.plugins.*

fun main(args: Array<String>): Unit =
    io.ktor.server.netty.EngineMain.main(args)

@Suppress("unused") // application.conf references the main function. This annotation prevents the IDE from marking it as unused.
fun Application.module() {
    install(IgnoreTrailingSlash)
    checkCacheVersion()
    configureSerialization()
    configureRouting()
}
