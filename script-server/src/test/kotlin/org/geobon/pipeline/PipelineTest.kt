package org.geobon.pipeline

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.geobon.script.outputRoot
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import java.io.File
import kotlin.test.assertContains

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

        assertEquals(1, allOutputs.size)
        assertTrue(allOutputs.any { it.key.contains("HelloPython.yml") })

        pipeline.execute()
        assertEquals(19 + 1.0, pipeline.getPipelineOutputs()[0].pull())
    }

    @Test
    fun `given a no-script pipeline_when built and ran_then constant is there_output can be retrieved`() = runTest {
        val pipeline = Pipeline("0in1out_noStep.json")

        val allOutputs = mutableMapOf<String, String>()
        pipeline.dumpOutputFolders(allOutputs)

        assertEquals(0, allOutputs.size)

        pipeline.execute()
        assertEquals(19, pipeline.getPipelineOutputs()[0].pull())
    }

    @Test
    fun `given a pipeline with outputs from many scripts_when ran_then all outputs satisfied_no step is duplicated in output dump`() = runTest {
        val pipeline = Pipeline("0in2out_twoBranches.json")

        val allOutputs = mutableMapOf<String, String>()
        pipeline.dumpOutputFolders(allOutputs)

        assertEquals(4, allOutputs.size)

        pipeline.execute()

        with(listOf(pipeline.getPipelineOutputs()[0].pull(), pipeline.getPipelineOutputs()[1].pull())) {
            assertContains(this, 21.0)
            assertContains(this, 22.0)
        }
    }

    @Test
    fun `given a pipeline with two disconnected pipelines_when ran_then both are run`() = runTest {
        val pipeline = Pipeline("0in2out_parallelPipelines.json")

        val allOutputs = mutableMapOf<String, String>()
        pipeline.dumpOutputFolders(allOutputs)

        assertEquals(4, allOutputs.size)

        pipeline.execute()

        with(listOf(pipeline.getPipelineOutputs()[0].pull(), pipeline.getPipelineOutputs()[1].pull())) {
            assertContains(this, 5.0)
            assertContains(this, 22.0)
        }
    }

    @Test
    fun `given a pipeline receives an array_when ran_then input json created with array`() = runTest {
        val pipeline = Pipeline("arrayConst.json")

        pipeline.execute()

        assertEquals(
            """{"array":[11,12,13]}""",
            outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!!.filter { it.name == "input.json" }[0].readText())
    }

    // TODO: With cache: Test that a script will not be ran again if already running. We should be able to listen to it, even if it this is in *another* pipeline!
}