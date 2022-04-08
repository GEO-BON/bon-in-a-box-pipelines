package org.geobon.pipeline

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.geobon.script.outputRoot
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import java.io.File

@ExperimentalCoroutinesApi
internal class PipelineTest {
    @BeforeEach
    fun setupOutputFolder() {
        with(outputRoot) {
            assertTrue(!exists())
            mkdirs()
            assertTrue(exists())
        }
    }

    @AfterEach
    fun removeOutputFolder() {
        assertTrue(File(System.getenv("OUTPUT_LOCATION")).deleteRecursively())
    }

    @Test
    fun `given a single script pipeline_when building from json_then node is there`() = runTest {
        val pipeline = Pipeline("0in1out_1step.json")

        val allOutputs = mutableMapOf<String, String>()
        pipeline.dumpOutputFolders(allOutputs)

        assertEquals(2, allOutputs.size) // The constant and the script. Should we output the constant?
        assertTrue(allOutputs.any { it.key.contains("HelloPython.yml") })

        pipeline.execute()
        assertEquals(123456 + 1, pipeline.getPipelineOutputs()[0])
    }

    @Test
    fun `given a no-script pipeline_when built and ran_then constant is there_execute is a no-op_output can be retrieved`() = runTest {
        // TODO
    }

    @Test
    fun `given a pipeline with outputs from many scripts_when ran_then all outputs satisfied_no step is duplicated in output dump`() = runTest {
        // TODO
    }

    @Test
    fun `given a pipeline with two disconnected pipelines_when ran_then both are run`() = runTest {
        // TODO
    }



    // TODO: test against infinite loops when using dumpOutputs (if already in map, do not pass it on!)

    // TODO: With cache: Test that a script will not be ran again if already running. We should be able to listen to it, even it this is in *another* pipeline!
}