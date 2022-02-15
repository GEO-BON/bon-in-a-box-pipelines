/**
 * BON in a Box - Script service
 */
package org.openapitools.server.apis

import io.ktor.application.*
import io.ktor.http.*
import io.ktor.locations.*
import io.ktor.request.*
import io.ktor.response.*
import io.ktor.routing.*
import org.geobon.script.ScriptRun
import org.geobon.script.scriptRoot
import org.openapitools.server.Paths
import org.slf4j.Logger
import java.io.File

/**
 * Used to transport paths through path param.
 * Folder tree not supported, see https://github.com/OAI/OpenAPI-Specification/issues/892
 */
const val FILE_SEPARATOR = '>'

@KtorExperimentalLocationsAPI
fun Route.ScriptApi(logger:Logger) {

    get<Paths.getScriptInfo> { parameters ->
        try {
            // Put back the slashes and replace extension by .yml
            val ymlPath = parameters.scriptPath.replace(FILE_SEPARATOR, '/').replace(Regex("""\.\w+$"""), ".yml")
            val scriptFile = File(scriptRoot, ymlPath)
            call.respondText(scriptFile.readText())
            logger.trace("200: Paths.getScriptInfo $scriptFile")
        } catch (ex:Exception) {
            call.respondText(text=ex.message!!, status=HttpStatusCode.NotFound)
            logger.trace("Error 404: Paths.getScriptInfo ${parameters.scriptPath}")
        }
    }

    post<Paths.runScript> { parameters ->
        val inputFileContent = call.receive<String>()
        logger.info("scriptPath: ${parameters.scriptPath}\nbody:$inputFileContent")

        val scriptRelPath = parameters.scriptPath.replace(FILE_SEPARATOR, '/')
        val script = ScriptRun(scriptRelPath, inputFileContent)
        script.execute()
        script.result?.let { call.respond(HttpStatusCode.OK, it) }
            ?: call.respond(HttpStatusCode.InternalServerError)
    }

    get<Paths.scriptListGet> {
        val possible = mutableListOf<String>()
        val relPathIndex = scriptRoot.absolutePath.length + 1
        scriptRoot.walkTopDown().forEach { file ->
            if(file.extension == "yml") {
                // Add the relative path, without the script root.
                possible.add(file.absolutePath.substring(relPathIndex).replace('/', FILE_SEPARATOR))
            }
        }
        
        call.respond(possible)
    }
}
