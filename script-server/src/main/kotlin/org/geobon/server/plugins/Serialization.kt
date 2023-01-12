package org.geobon.server.plugins

import io.ktor.serialization.gson.*
import io.ktor.server.plugins.contentnegotiation.*
import io.ktor.server.application.*
import io.ktor.server.response.*
import io.ktor.server.request.*
import io.ktor.server.routing.*

fun Application.configureSerialization() {
    install(ContentNegotiation) {
        gson {
            }
    }

    routing {
        get("/json/gson") {
                call.respond(mapOf("hello" to "world"))
            }
    }
}
