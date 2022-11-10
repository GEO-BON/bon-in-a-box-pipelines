package org.geobon.pipeline

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.geobon.script.outputRoot
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
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
        assertTrue(outputRoot.deleteRecursively())
    }

    @Test
    fun `given a single script pipeline_when building from json_then node is there`() = runTest {
        val pipeline = Pipeline("0in1out_1step.json")

        val allOutputs = mutableMapOf<String, String>()
        pipeline.dumpOutputFolders(allOutputs)

        assertEquals(1, allOutputs.size)
        assertTrue(allOutputs.any { it.key.contains("helloPython.yml") })

        pipeline.execute()
        assertEquals(19 + 1, pipeline.getPipelineOutputs()[0].pull())
    }

    @Test
    fun `given a pipeline with outputs from many scripts_when ran_then all outputs satisfied_no step is duplicated in output dump`() = runTest {
        val pipeline = Pipeline("0in2out_twoBranches.json")

        val allOutputs = mutableMapOf<String, String>()
        pipeline.dumpOutputFolders(allOutputs)

        assertEquals(4, allOutputs.size)

        pipeline.execute()

        with(listOf(pipeline.getPipelineOutputs()[0].pull(), pipeline.getPipelineOutputs()[1].pull())) {
            assertContains(this, 21)
            assertContains(this, 22)
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
            assertContains(this, 5)
            assertContains(this, 22)
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
        val pipeline = Pipeline("aggregateInt.json")

        pipeline.execute()

        assertEquals(
            """{"array":[11,12,13]}""",
            outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!!.filter { it.name == "input.json" }[0].readText())
    }


    @Test
    fun `given an int and int array aggregation_when ran_then script receives single array`() = runTest {
        val pipeline = Pipeline("aggregateIntAndIntArray.json")

        pipeline.execute()

        assertEquals(
            """{"array":[11,12,13]}""",
            outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!!.filter { it.name == "input.json" }[0].readText())
    }

    @Test
    fun `given an int while step awaits an array_when ran_then int wrapped in array`() = runTest {
        val pipeline = Pipeline("wrapIntTowardsArray.json")

        pipeline.execute()

        assertEquals(listOf(234), pipeline.getPipelineOutputs()[0].pull())
    }

    @Test
    fun `given a pipeline with boolean constant_when ran_then script input json created with boolean`() = runTest {
        val pipeline = Pipeline("boolConst.json")

        pipeline.execute()

        assertEquals(
            """{"input_bool":true}""",
            outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!!.filter { it.name == "input.json" }[0].readText())
    }

    @Test
    fun `given a pipeline with an input_when ran_then the provided input is used`() = runTest {
        val pipeline = Pipeline("1in1out_1step.json", """{ "helloWorld>helloPython.yml@0.some_int": 5 }""")
        pipeline.execute()

        assertEquals(6, pipeline.getPipelineOutputs()[0].pull())
    }

    @Test
    fun `given a pipeline with a malformed input name_when built_then an exception is thrown`() = runTest {
        assertThrows<RuntimeException> { // missing @
            Pipeline("1in1out_1step.json", """ { "helloWorld>helloPython.yml0.some_int": 5 }""")
        }

        assertThrows<RuntimeException> { // missing step id
            Pipeline("1in1out_1step.json", """ { "helloWorld>helloPython.yml@.some_int": 5 }""")
        }

        assertThrows<RuntimeException> { // missing everything
            Pipeline("1in1out_1step.json", """ { "@.": 5 }""")
        }

        assertThrows<RuntimeException> { // plausible case where a non-existant script path is used
            Pipeline("1in1out_1step.json", """ { "HelloWorld>BAD@0.some_int": 5 }""")
        }

        assertThrows<RuntimeException> { // non-numeric step id
            Pipeline("1in1out_1step.json", """ { "helloWorld>helloPython.yml@BAD.some_int": 5 }""")
        }

        assertThrows<RuntimeException> { // plausible case where a non-existent step id is used
            Pipeline("1in1out_1step.json", """ { "helloWorld>helloPython.yml@72.some_int": 5 }""")
        }
    }

    @Test
    fun `given a pipeline passing float_when ran_then a float value is received`() = runTest {
        val pipeline = Pipeline("assertFloat.json")
        pipeline.execute()
    }

    @Test
    fun `given a pipeline passing int_when ran_then an int value is received`() = runTest {
        val pipeline = Pipeline("assertInt.json")
        pipeline.execute()
    }

    @Test
    fun `given a pipeline passing int to float_when ran_then float input accepts int input`() = runTest {
        val pipeline = Pipeline("intToFloat.json", """ { "1in1out.yml@1.some_int": 3, "divideFloat.yml@0.divider": 2 }""")
        pipeline.execute()
        assertTrue(pipeline.getPipelineOutputs()[0].pull() == 2)
    }

}