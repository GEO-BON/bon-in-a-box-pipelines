package org.geobon.pipeline

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.geobon.pipeline.Pipeline.Companion.createMiniPipelineFromScript
import org.geobon.pipeline.Pipeline.Companion.createRootPipeline
import java.io.File
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
        val pipeline = createRootPipeline("0in1out_1step.json")

        val allOutputs = mutableMapOf<String, String>()
        pipeline.dumpOutputFolders(allOutputs)

        assertEquals(1, allOutputs.size)
        assertTrue(allOutputs.any { it.key.contains("helloPython.yml") })

        pipeline.pullFinalOutputs()
        assertEquals(19 + 1, pipeline.getPipelineOutputs()[0].pull())
    }

    @Test
    fun `given a pipeline with outputs from many scripts_when ran_then all outputs satisfied_no step is duplicated in output dump`() = runTest {
        val pipeline = createRootPipeline("0in2out_twoBranches.json")

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
        val pipeline = createRootPipeline("0in2out_parallelPipelines.json")

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
        val pipeline = createRootPipeline("arrayConst.json")

        pipeline.pullFinalOutputs()

        assertEquals(
            """{"array":[11,12,13]}""",
            outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!!.filter { it.name == "input.json" }[0].readText())
    }

    @Test
    fun `given an int aggregation_when ran_then script receives array`() = runTest {
        val pipeline = createRootPipeline("aggregateInt.json")

        pipeline.pullFinalOutputs()

        assertEquals(
            """{"array":[11,12,13]}""",
            outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!!.filter { it.name == "input.json" }[0].readText())
    }


    @Test
    fun `given an int and int array aggregation_when ran_then script receives single array`() = runTest {
        val pipeline = createRootPipeline("aggregateIntAndIntArray.json")

        pipeline.pullFinalOutputs()

        assertEquals(
            """{"array":[11,12,13]}""",
            outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!!.filter { it.name == "input.json" }[0].readText())
    }

    @Test
    fun `given an int while step awaits an array_when ran_then int wrapped in array`() = runTest {
        val pipeline = createRootPipeline("wrapIntTowardsArray.json")

        pipeline.pullFinalOutputs()

        assertEquals(listOf(234), pipeline.getPipelineOutputs()[0].pull())
    }

    @Test
    fun `given a pipeline with boolean constant_when ran_then script input json created with boolean`() = runTest {
        val pipeline = createRootPipeline("boolConst.json")

        pipeline.pullFinalOutputs()

        assertEquals(
            """{"input_bool":true}""",
            outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!!.filter { it.name == "input.json" }[0].readText())
    }

    @Test
    fun `given a pipeline with an input_when ran_then the provided input is used`() = runTest {
        val pipeline = createRootPipeline("1in1out_1step.json", """{ "helloWorld>helloPython.yml@0|some_int": 5 }""")
        pipeline.pullFinalOutputs()

        assertEquals(6, pipeline.getPipelineOutputs()[0].pull())
    }

    @Test
    fun `given a pipeline with a malformed input name_when built_then an exception is thrown`() = runTest {
        assertFailsWith<RuntimeException> { // missing @
            createRootPipeline("1in1out_1step.json", """ { "helloWorld>helloPython.yml0|some_int": 5 }""")
        }

        assertFailsWith<RuntimeException> { // missing step id
            createRootPipeline("1in1out_1step.json", """ { "helloWorld>helloPython.yml@|some_int": 5 }""")
        }

        assertFailsWith<RuntimeException> { // missing everything
            createRootPipeline("1in1out_1step.json", """ { "@|": 5 }""")
        }

        assertFailsWith<RuntimeException> { // plausible case where a non-existant script path is used
            createRootPipeline("1in1out_1step.json", """ { "HelloWorld>BAD@0|some_int": 5 }""")
        }

        assertFailsWith<RuntimeException> { // non-numeric step id
            createRootPipeline("1in1out_1step.json", """ { "helloWorld>helloPython.yml@BAD|some_int": 5 }""")
        }

        assertFailsWith<RuntimeException> { // plausible case where a non-existent step id is used
            createRootPipeline("1in1out_1step.json", """ { "helloWorld>helloPython.yml@72|some_int": 5 }""")
        }
    }

    @Test
    fun `given a pipeline passing float_when ran_then a float value is received`() = runTest {
        val pipeline = createRootPipeline("assertFloat.json")
        pipeline.pullFinalOutputs()
    }

    @Test
    fun `given a pipeline with null param_when ran_then a null value is received`() = runTest {
        val pipeline = createRootPipeline("assertNull.json", """{"assertNull.yml@0|input":null}""")
        pipeline.pullFinalOutputs()
        println(pipeline.outputs)
        assertNull(pipeline.outputs["assertNull.yml@1|the_same"]!!.value)
    }

    @Test
    fun `given a pipeline with null constant_when ran_then a null value is received`() = runTest {
        val pipeline = createRootPipeline("assertNull_fromConstant.json", "{}")
        pipeline.pullFinalOutputs()
        println(pipeline.outputs)
        assertNull(pipeline.outputs["assertNull.yml@1|the_same"]!!.value)
    }

    @Test
    fun `given a pipeline passing int_when ran_then an int value is received`() = runTest {
        val pipeline = createRootPipeline("assertInt.json")
        pipeline.pullFinalOutputs()
    }

    @Test
    fun `given a pipeline passing int to float_when ran_then float input accepts int input`() = runTest {
        val pipeline = createRootPipeline("intToFloat.json", """ { "1in1out.yml@1|some_int": 3, "divideFloat.yml@0|divider": 2 }""")
        pipeline.pullFinalOutputs()
        assertTrue(pipeline.getPipelineOutputs()[0].pull() == 2)
    }

    @Test
    fun `given a pipeline with userInput string_when ran_then input fed to child steps`() = runTest {
        val pipeline = createRootPipeline("userInput.json", """ { "pipeline@1": 10} """)
        pipeline.pullFinalOutputs()
        assertTrue(pipeline.getPipelineOutputs()[0].pull() == 11)
        assertTrue(pipeline.getPipelineOutputs()[1].pull() == 12)
    }

    @Test
    fun `given a pipeline with userInput string_when built with bad input id_then error message thrown`() = runTest {
        assertFailsWith<RuntimeException> {
            createRootPipeline("userInput.json", """ { "pipeline@3": 10} """)
        }
    }

    @Test
    fun `given a pipeline with userInput string_when built with bad input type_then error message thrown`() = runTest {
        assertFailsWith<RuntimeException> {
            createRootPipeline("userInput.json", """ { "pipeline@1": "A string?"} """)
        }
    }

    @Test
    fun `given a pipeline with userInput array_when ran_then input fed to child steps`() = runTest {
        val pipeline = createRootPipeline("userInput_array.json", """ {"pipeline@1":[3,4,5]} """)
        pipeline.pullFinalOutputs()
        assertEquals(listOf(3,4,5), pipeline.getPipelineOutputs()[0].pull())
    }

    @Test
    fun `given a nested pipeline with input left blank_when ran_then it behaves as a single pipeline`() = runTest {
        val pipeline = createRootPipeline("pipelineInPipeline/inputLeftBlank.json",
            """ {"1in1out_1step.json@1|helloWorld>helloPython.yml@0|some_int":3} """)

        val allOutputs = mutableMapOf<String, String>()
        pipeline.dumpOutputFolders(allOutputs)
        assertEquals(2, allOutputs.size)

        pipeline.pullFinalOutputs()
        assertEquals(5, pipeline.getPipelineOutputs()[0].pull())
    }


    @Test
    fun `given a nested pipeline with a user input_when ran_then it behaves as a single pipeline`() = runTest {
        val pipeline = createRootPipeline("pipelineInPipeline/userInputInside.json",
            """ {"userInput.json@0|pipeline@1":20} """)

        val allOutputs = mutableMapOf<String, String>()
        pipeline.dumpOutputFolders(allOutputs)
        assertEquals(3, allOutputs.size)

        pipeline.pullFinalOutputs()

        assertEquals(22, pipeline.outputs["userInput.json@0|helloWorld>helloPython.yml@5|increment"]!!.pull())
        assertEquals(21, pipeline.outputs["userInput.json@0|helloWorld>helloPython.yml@2|increment"]!!.pull())
    }



    @Test
    fun `given a nested pipeline receiving a user input_when ran_then it behaves as a single pipeline`() = runTest {
        val pipeline = createRootPipeline("pipelineInPipeline/userInputOutside.json",
            """ {"pipeline@3":5} """)

        val allOutputs = mutableMapOf<String, String>()
        pipeline.dumpOutputFolders(allOutputs)
        assertEquals(3, allOutputs.size)

        pipeline.pullFinalOutputs()

        assertEquals(6, pipeline.outputs["helloWorld>helloPython.yml@4|increment"]!!.pull())
        assertEquals(7, pipeline.outputs["userInput.json@0|helloWorld>helloPython.yml@5|increment"]!!.pull())
    }

    @Test
    fun `given a nested pipeline with two branches_when ran_then only the necessary branch runs`() = runTest {
        val pipeline = createRootPipeline("pipelineInPipeline/twoBranchTest.json",
            """ {"twoBranches.json@14|divideFloat.yml@5|divider":2} """)

        val result = pipeline.pullFinalOutputs()

        // No output folder fo assertFloat
        assertTrue(File(outputRoot, "divideFloat").isDirectory)
        assertFalse(File(outputRoot, "assertFloat").isDirectory)

        // The excluded one should not figure in the results
        assertContains(result.keys, "helloWorld>helloPython.yml@16") // The increment
        assertContains(result.keys, "twoBranches.json@14|divideFloat.yml@5") // The division
        assertFalse(result.keys.contains("twoBranches.json@14|assertFloat.yml@4")) // The assertion should not be there

        // Result should still be valid
        assertEquals(6, pipeline.outputs["twoBranches.json@14|divideFloat.yml@5|result"]!!.pull())
    }

    @Test
    fun `given a mini pipeline_when ran_then outputs generated`() = runTest {
        val pipeline = createMiniPipelineFromScript(
            File(RunContext.scriptRoot, "helloWorld/helloPython.yml"),
            "helloWorld>helloPython.yml",
            """{ "some_int": "7" }"""
        )

        val outputs = pipeline.pullFinalOutputs()
        val scriptOutputDir = File(outputRoot, outputs["helloWorld>helloPython.yml@1"]!!)
        val scriptOutputFile = File(scriptOutputDir, "output.json")
        assertTrue(scriptOutputFile.exists())

        // The results are there
        assertContains(scriptOutputFile.readText(), "\"increment\": 8")
    }

    @Test
    fun `given a mini pipeline_when ran with bad key_then exception occurs`() = runTest {
        assertFailsWith<RuntimeException> {
            createMiniPipelineFromScript(
                File(RunContext.scriptRoot, "helloWorld/helloPython.yml"),
                "helloWorld>helloPython.yml",
                """{ "bad_key": "7" }"""
            )
        }
    }
}