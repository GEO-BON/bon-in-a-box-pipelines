package org.geobon.pipeline

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import kotlin.test.*

@ExperimentalCoroutinesApi
internal class PipelineTest {
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
    fun `given a single script pipeline_when building from json_then node is there`() = runTest {
        val pipeline = RootPipeline("0in1out_1step.json")

        val allOutputs = mutableMapOf<String, String>()
        pipeline.dumpOutputFolders(allOutputs)

        assertEquals(1, allOutputs.size)
        assertTrue(allOutputs.any { it.key.contains("helloPython.yml") })

        pipeline.pullFinalOutputs()
        assertEquals(19 + 1, pipeline.getPipelineOutputs()[0].pull())
    }

    @Test
    fun `given a pipeline with outputs from many scripts_when ran_then all outputs satisfied_no step is duplicated in output dump`() = runTest {
        val pipeline = RootPipeline("0in2out_twoBranches.json")

        val allOutputs = mutableMapOf<String, String>()
        pipeline.dumpOutputFolders(allOutputs)

        assertEquals(4, allOutputs.size)

        pipeline.pullFinalOutputs()

        with(listOf(pipeline.getPipelineOutputs()[0].pull(), pipeline.getPipelineOutputs()[1].pull())) {
            assertContains(this, 21)
            assertContains(this, 22)
        }
    }

    @Test
    fun `given a pipeline with two disconnected pipelines_when ran_then both are run`() = runTest {
        val pipeline = RootPipeline("0in2out_parallelPipelines.json")

        val allOutputs = mutableMapOf<String, String>()
        pipeline.dumpOutputFolders(allOutputs)

        assertEquals(4, allOutputs.size)

        pipeline.pullFinalOutputs()

        with(listOf(pipeline.getPipelineOutputs()[0].pull(), pipeline.getPipelineOutputs()[1].pull())) {
            assertContains(this, 5)
            assertContains(this, 22)
        }
    }

    @Test
    fun `given a pipeline with constant array_when ran_then input json created with array`() = runTest {
        val pipeline = RootPipeline("arrayConst.json")

        pipeline.pullFinalOutputs()

        assertEquals(
            """{"array":[11,12,13]}""",
            outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!!.filter { it.name == "input.json" }[0].readText())
    }

    @Test
    fun `given an int aggregation_when ran_then script receives array`() = runTest {
        val pipeline = RootPipeline("aggregateInt.json")

        pipeline.pullFinalOutputs()

        assertEquals(
            """{"array":[11,12,13]}""",
            outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!!.filter { it.name == "input.json" }[0].readText())
    }


    @Test
    fun `given an int and int array aggregation_when ran_then script receives single array`() = runTest {
        val pipeline = RootPipeline("aggregateIntAndIntArray.json")

        pipeline.pullFinalOutputs()

        assertEquals(
            """{"array":[11,12,13]}""",
            outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!!.filter { it.name == "input.json" }[0].readText())
    }

    @Test
    fun `given an int while step awaits an array_when ran_then int wrapped in array`() = runTest {
        val pipeline = RootPipeline("wrapIntTowardsArray.json")

        pipeline.pullFinalOutputs()

        assertEquals(listOf(234), pipeline.getPipelineOutputs()[0].pull())
    }

    @Test
    fun `given a pipeline with boolean constant_when ran_then script input json created with boolean`() = runTest {
        val pipeline = RootPipeline("boolConst.json")

        pipeline.pullFinalOutputs()

        assertEquals(
            """{"input_bool":true}""",
            outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!!.filter { it.name == "input.json" }[0].readText())
    }

    @Test
    fun `given a pipeline with an input_when ran_then the provided input is used`() = runTest {
        val pipeline = RootPipeline("1in1out_1step.json", """{ "helloWorld>helloPython.yml@0|some_int": 5 }""")
        pipeline.pullFinalOutputs()

        assertEquals(6, pipeline.getPipelineOutputs()[0].pull())
    }

    @Test
    fun `given a pipeline with a malformed input name_when built_then an exception is thrown`() = runTest {
        assertFailsWith<RuntimeException> { // missing @
            RootPipeline("1in1out_1step.json", """ { "helloWorld>helloPython.yml0|some_int": 5 }""")
        }

        assertFailsWith<RuntimeException> { // missing step id
            RootPipeline("1in1out_1step.json", """ { "helloWorld>helloPython.yml@|some_int": 5 }""")
        }

        assertFailsWith<RuntimeException> { // missing everything
            RootPipeline("1in1out_1step.json", """ { "@|": 5 }""")
        }

        assertFailsWith<RuntimeException> { // plausible case where a non-existant script path is used
            RootPipeline("1in1out_1step.json", """ { "HelloWorld>BAD@0|some_int": 5 }""")
        }

        assertFailsWith<RuntimeException> { // non-numeric step id
            RootPipeline("1in1out_1step.json", """ { "helloWorld>helloPython.yml@BAD|some_int": 5 }""")
        }

        assertFailsWith<RuntimeException> { // plausible case where a non-existent step id is used
            RootPipeline("1in1out_1step.json", """ { "helloWorld>helloPython.yml@72|some_int": 5 }""")
        }
    }

    @Test
    fun `given a pipeline passing float_when ran_then a float value is received`() = runTest {
        val pipeline = RootPipeline("assertFloat.json")
        pipeline.pullFinalOutputs()
    }

    @Test
    fun `given a pipeline passing int_when ran_then an int value is received`() = runTest {
        val pipeline = RootPipeline("assertInt.json")
        pipeline.pullFinalOutputs()
    }

    @Test
    fun `given a pipeline passing int to float_when ran_then float input accepts int input`() = runTest {
        val pipeline = RootPipeline("intToFloat.json", """ { "1in1out.yml@1|some_int": 3, "divideFloat.yml@0|divider": 2 }""")
        pipeline.pullFinalOutputs()
        assertTrue(pipeline.getPipelineOutputs()[0].pull() == 2)
    }

    @Test
    fun `given a pipeline with userInput string_when ran_then input fed to child steps`() = runTest {
        val pipeline = RootPipeline("userInput.json", """ { "pipeline@1": 10} """)
        pipeline.pullFinalOutputs()
        assertTrue(pipeline.getPipelineOutputs()[0].pull() == 11)
        assertTrue(pipeline.getPipelineOutputs()[1].pull() == 12)
    }

    @Test
    fun `given a pipeline with userInput string_when built with bad input id_then error message thrown`() = runTest {
        assertFailsWith<RuntimeException> {
            RootPipeline("userInput.json", """ { "pipeline@3": 10} """)
        }
    }

    @Test
    fun `given a pipeline with userInput string_when built with bad input type_then error message thrown`() = runTest {
        assertFailsWith<RuntimeException> {
            RootPipeline("userInput.json", """ { "pipeline@1": "A string?"} """)
        }
    }

    @Test
    fun `given a pipeline with userInput array_when ran_then input fed to child steps`() = runTest {
        val pipeline = RootPipeline("userInput_array.json", """ {"pipeline@1":[3,4,5]} """)
        pipeline.pullFinalOutputs()
        assertEquals(listOf(3,4,5), pipeline.getPipelineOutputs()[0].pull())
    }

    @Test
    fun `given a nested pipeline with input left blank_when ran_it behaves as a single pipeline`() = runTest {
        val pipeline = RootPipeline("pipelineInPipeline/inputLeftBlank.json",
            """ {"1in1out_1step.json@1|helloWorld>helloPython.yml@0|some_int":3} """)
        pipeline.pullFinalOutputs()
        assertEquals(5, pipeline.getPipelineOutputs()[0].pull())
    }


    @Test
    fun `given a nested pipeline with a user input_when ran_it behaves as a single pipeline`() = runTest {
        val pipeline = RootPipeline("pipelineInPipeline/userInputInside.json",
            """ {"userInput.json@0|pipeline@1":20} """)

        pipeline.pullFinalOutputs()

        assertEquals(22, pipeline.outputs["userInput.json@0|helloWorld>helloPython.yml@5|increment"]!!.pull())
        assertEquals(21, pipeline.outputs["userInput.json@0|helloWorld>helloPython.yml@2|increment"]!!.pull())
    }



    @Test
    fun `given a nested pipeline receiving a user input_when ran_it behaves as a single pipeline`() = runTest {
        val pipeline = RootPipeline("pipelineInPipeline/userInputOutside.json",
            """ {"pipeline@3":5} """)
        pipeline.pullFinalOutputs()

        assertEquals(6, pipeline.outputs["helloWorld>helloPython.yml@4|increment"]!!.pull())
        assertEquals(7, pipeline.outputs["userInput.json@0|helloWorld>helloPython.yml@5|increment"]!!.pull())
    }
}