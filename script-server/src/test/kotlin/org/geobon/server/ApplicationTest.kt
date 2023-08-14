package org.geobon.server

import io.ktor.client.request.*
import io.ktor.client.statement.*
import io.ktor.http.*
import io.ktor.server.testing.*
import org.geobon.pipeline.outputRoot
import org.geobon.server.plugins.configureRouting
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import kotlin.test.*

class ApplicationTest {

    @BeforeTest
    fun setupOutputFolder() {
        with(outputRoot) {
            assertTrue(!exists())
            mkdirs()
            assertTrue(exists())
        }
    }

    @AfterTest
    fun removeOutputFolder() {
        assertTrue(outputRoot.deleteRecursively())
    }

    @Test
    fun testPipelineRun() = testApplication {

        client.get("/pipeline/list").apply {
            assertEquals(HttpStatusCode.OK, status)
            val result = bodyAsText()
            val jsonResult = JSONArray(result)
            assertTrue(jsonResult.length() > 0)
            assertContains(jsonResult, "helloWorld.json")
        }

        var id:String
        client.post("/pipeline/helloWorld.json/run") {
            setBody("{\"helloWorld>helloPython.yml@0|some_int\":1}")
        }.apply {
            assertEquals(HttpStatusCode.OK, status)
            id = bodyAsText()
        }


        client.get("/pipeline/$id/outputs").apply {
            val result = JSONObject(bodyAsText())
            println(result)

            val folder = File(
                outputRoot,
                result.getString(result.keys().next()))
            assertTrue(folder.isDirectory)

            val files = folder.listFiles()
            assertTrue(files!!.size == 3, "Expected input, output and log files to be there.\nFound ${files.toList()}")
        }
    }

    @Test
    fun testScriptRun() = testApplication {

        client.get("/script/list").apply {
            assertEquals(HttpStatusCode.OK, status)
            val result = bodyAsText()
            val jsonResult = JSONArray(result)
            assertTrue(jsonResult.length() > 0)
            assertContains(jsonResult, "helloWorld>helloPython.yml")
        }

        var id:String
        client.post("/script/helloWorld>helloPython.yml/run") {
            setBody("{\"some_int\":1}")
        }.apply {
            assertEquals(HttpStatusCode.OK, status)
            id = bodyAsText()
        }

        client.get("/script/$id/outputs").apply {
            val result = JSONObject(bodyAsText())

            val folder = File(
                outputRoot,
                result.getString(result.keys().next()))
            assertTrue(folder.isDirectory)

            val files = folder.listFiles()
            assertTrue(files!!.size == 4, "Expected input, pipeline output, script output and log files to be there.\nFound ${files.toList()}")

            assertEquals("""
                {
                  "increment": 2
                }""".trimIndent(),
                File(folder, "output.json").readText()
            )
        }
    }

    @Test
    fun testPipelineWithSubfolder() = testApplication {

        var id: String
        client.post("/pipeline/subfolder>in_subfolder.json/run") {
            setBody("{\"helloWorld>helloPython.yml@0|some_int\":1}")
        }.apply {
            assertEquals(HttpStatusCode.OK, status)
            id = bodyAsText()
        }

        client.get("/pipeline/$id/outputs").apply {
            val result = JSONObject(bodyAsText())
            println(result)

            val folder = File(
                outputRoot,
                result.getString(result.keys().next())
            )
            assertTrue(folder.isDirectory)

            val files = folder.listFiles()
            assertTrue(files!!.size >= 3, "Expected input, output and log files to be there.\nFound ${files.toList()}")
        }
    }

    @Test
    fun testIgnoreTrailingSlash() = testApplication {

        client.get("/pipeline/list").apply {
            assertEquals(HttpStatusCode.OK, status)
        }

        client.get("/pipeline/list/").apply {
            assertEquals(HttpStatusCode.OK, status)
        }
    }
}