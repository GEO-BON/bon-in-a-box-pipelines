/**
 * BON in a Box - Script service
 */
package org.openapitools.server.apis

import com.google.gson.Gson
import io.ktor.application.*
import io.ktor.auth.*
import io.ktor.http.*
import io.ktor.response.*
import org.openapitools.server.Paths
import io.ktor.locations.*
import io.ktor.routing.*
import org.openapitools.server.infrastructure.ApiPrincipal
import org.openapitools.server.models.ScriptRunResult
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import java.io.File

val scriptFolder = System.getenv("SCRIPT_LOCATION")

@KtorExperimentalLocationsAPI
fun Route.ScriptRunner(logger:Logger) {

    get<Paths.getScriptInfo> { parameters ->
        try {
            // Replace extension by .md
            val mdPath = parameters.scriptPath.replace(Regex("""\.\w+$"""), ".md")
            val scriptFile = File(scriptFolder, mdPath)
            call.respondText(scriptFile.readText())
            logger.trace("200: getScriptInfo $scriptFile")
        } catch (ex:Exception) {
            call.respondText(text=ex.message!!, status=HttpStatusCode.NotFound)
            logger.trace("Error 404: getScriptInfo ${parameters.scriptPath}")
        }
    }

    val gson = Gson()
    val empty = mutableMapOf<String, Any?>()
    get<Paths.runScript> { parameters ->
        val exampleContentType = "application/json"
        val exampleContentString = """{
          "files" : {
            "presence" : "presence.tiff",
            "uncertainty" : "uncertainty.tiff"
          },
          "logs" : "Starting... Script completed!"
        }"""
        
        logger.info("scriptPath: ${parameters.scriptPath}")
        parameters.params?.forEach { param -> logger.info("param: $param") }
        
        when (exampleContentType) {
            "application/json" -> call.respond(gson.fromJson(exampleContentString, empty::class.java))
            "application/xml" -> call.respondText(exampleContentString, ContentType.Text.Xml)
            else -> call.respondText(exampleContentString)
        }
    }

}
