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
    fun `given a pipeline with constant array_when ran_then input json created with array`() = runTest {
        val pipeline = Pipeline("arrayConst.json")

        pipeline.execute()

        assertEquals(
            """{"array":[11,12,13]}""",
            outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!!.filter { it.name == "input.json" }[0].readText())
    }

    @Test
    fun `given an int aggregation_when ran_then script receives array`() = runTest {
        val pipeline = Pipeline("aggregateIntAndIntArray.json")

        pipeline.execute()

        assertEquals(
            """{"array":[11,12,13]}""",
            outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!!.filter { it.name == "input.json" }[0].readText())
    }


    @Test
    fun `given an int and int array aggregation_when ran_then script receives single array`() = runTest {
        val pipeline = Pipeline("aggregateInt.json")

        pipeline.execute()

        assertEquals(
            """{"array":[11,12,13]}""",
            outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!!.filter { it.name == "input.json" }[0].readText())
    }

    @Test
    fun `given a pipeline with boolean constant_when ran_then script input json created with boolean`() = runTest {
        val pipeline = Pipeline("boolConst.json")

        pipeline.execute()

        assertEquals(
            """{"input_bool":true}""",
            outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!!.filter { it.name == "input.json" }[0].readText())
    }

}