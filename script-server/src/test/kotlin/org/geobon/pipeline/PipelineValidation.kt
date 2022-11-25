package org.geobon.pipeline

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.geobon.utils.withProductionPaths
import org.geobon.utils.productionPipelinesRoot
import org.json.JSONObject
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import java.io.File
import kotlin.test.fail

@ExperimentalCoroutinesApi
internal class PipelineValidation {

    @BeforeEach
    fun setupOutputFolder() {

    }

    @AfterEach
    fun removeOutputFolder() {
    }

    private fun validateAllPipelines(directory: File): String {
        var errorMessages = ""
        directory.listFiles()?.forEach { file ->
            if (file.isDirectory) {
                validateAllPipelines(file)
            } else {
                // Generate fake inputs
                val fakeInputs = JSONObject()
                val pipelineJSON = JSONObject(file.readText())
                pipelineJSON.optJSONObject(INPUTS)?.let { inputsSpec ->
                    inputsSpec.keySet().forEach { key ->
                        inputsSpec.optJSONObject(key)?.let { inputSpec ->
                            fakeInputs.put(key, inputSpec.get(INPUTS__EXAMPLE))
                        }
                    }
                }
                println(fakeInputs.toString(2))

                try { // Run validation
                    Pipeline(file, fakeInputs.toString(2))
                } catch (e: Exception) {
                    errorMessages += "${file.relativeTo(productionPipelinesRoot)}:\n\t${e.message}\n"
                }
            }
        }

        return errorMessages
    }

    @Test
    fun runValidationOnAllPipelines() = runTest {
        withProductionPaths {
            val errorMessage = validateAllPipelines(productionPipelinesRoot)
            if (errorMessage.isNotEmpty()) {
                fail(errorMessage)
            }
        }
    }
}