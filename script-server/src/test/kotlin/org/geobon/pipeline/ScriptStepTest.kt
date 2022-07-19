package org.geobon.pipeline

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.geobon.script.outputRoot
import org.geobon.script.scriptRoot
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import java.io.File

@ExperimentalCoroutinesApi
internal class ScriptStepTest {

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
    fun givenNoInput_whenExecute_thenNoInputFileIsGenerated_andOutputIsThere() = runTest {
        val step = ScriptStep(File(scriptRoot, "0in1out.yml"))
        assertTrue(step.validateGraph().isEmpty())

        step.execute()

        val files = outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!!
        assertEquals(0, files.filter { it.name == "input.json" }.size)
        assertEquals(1, files.filter { it.name == "output.json" }.size)

        assertNotNull(step.outputs["randomness"])
        assertNotNull(step.outputs["randomness"]!!.value)
        assertEquals(234.toDouble(), step.outputs["randomness"]!!.value as Double)
    }

    @Test
    fun given1In1Out_whenExecute_thenInputFileIsGenerated_andOutputIsThere() = runTest {
        val input = 234
        val step = ScriptStep(File(scriptRoot, "1in1out.yml"), mutableMapOf("some_int" to ConstantPipe("int", input)))
        assertTrue(step.validateGraph().isEmpty())

        step.execute()

        val files = outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!!
        files.filter { it.name == "input.json" }.let {
            assertEquals(1, it.size)
            println(it[0]!!.readText())
        }

        assertEquals(1, files.filter { it.name == "output.json" }.size)
        assertNotNull(step.outputs["increment"])
        assertEquals((input + 1).toDouble(), step.outputs["increment"]!!.value as Double)
    }

    @Test
    fun givenScriptInSubfolder_whenExecute_thenOutputInSubfolder() = runTest {
        val step = ScriptStep(File(scriptRoot, "subfolder/inSubfolder.yml"))
        assertTrue(step.validateGraph().isEmpty())

        step.execute()

        // There is one additional listFiles                     here
        val files = outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!![0].listFiles()!!
        assertEquals(0, files.filter { it.name == "input.json" }.size)
        assertEquals(1, files.filter { it.name == "output.json" }.size)

        assertNotNull(step.outputs["randomness"])
        assertNotNull(step.outputs["randomness"]!!.value)
        assertEquals(234.toDouble(), step.outputs["randomness"]!!.value as Double)
    }

    @Test
    fun givenScriptStepThatHasNotRun_whenGettingOutputFolder_thenEmptyStringIsReturned() {
        val step = ScriptStep(File(scriptRoot, "subfolder/inSubfolder.yml"))
        assertTrue(step.validateGraph().isEmpty())
        val outputList = mutableMapOf<String, String>()
        step.dumpOutputFolders(outputList)

        assertEquals(1, outputList.size)
        outputList.forEach { assertEquals("", it.value) }
    }

    @Test
    fun givenScriptStepThatHasRun_whenGettingOutputFolder_thenGetOutputFolder() = runTest {
        val step = ScriptStep(File(scriptRoot, "subfolder/inSubfolder.yml"))
        assertTrue(step.validateGraph().isEmpty())
        val outputList = mutableMapOf<String, String>()

        step.execute()

        step.dumpOutputFolders(outputList)
        assertEquals(1, outputList.size)
        outputList.forEach {
            assertNotEquals("", it.value)
            assertTrue(File(outputRoot, it.value).exists())
        }
        println(outputList.toString())
    }

    @Test
    fun givenScriptStepThatHasRun_whenOutputFileEmpty_thenThrowsAndOutputHasError() = runTest {
        val step = ScriptStep(File(scriptRoot, "1in1out_noOutput.yml"), mutableMapOf("some_int" to ConstantPipe("int", 123)))
        assertTrue(step.validateGraph().isEmpty())

        try {
            step.execute()
            fail("Exception should have been thrown")
        } catch (_:Exception) {}

        val files = outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!!
        files.filter { it.name == "output.json" }.let {
            assertEquals(1, it.size)
            assertTrue(it[0]!!.readText().contains("\"error\""))
        }

    }

    @Test
    fun givenOptionsInput_whenReceivedValueNotInOptions_thenThrowsAndOutputHasError() = runTest {
        val step = ScriptStep(File(scriptRoot, "optionsInput.yml"),
            mutableMapOf("options_in" to ConstantPipe("options", "four")))
        step.validateGraph().apply { assertTrue(isEmpty(), "Validation error: $this") }

        try {
            step.execute()
            fail("Exception should have been thrown")
        } catch (_:Exception) {}

        /*val files = outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!!
        files.filter { it.name == "output.json" }.let {
            assertEquals(1, it.size)
            assertTrue(it[0]!!.readText().contains("\"error\""))
        }*/
    }

    @Test
    fun givenOptionsInput_whenReceivedValueInOptions_thenExecutes() = runTest {
        val step = ScriptStep(File(scriptRoot, "optionsInput.yml"),
            mutableMapOf("options_in" to ConstantPipe("options", "three")))
        step.validateGraph().apply { assertTrue(isEmpty(), "Validation error: $this") }

        step.execute()

        val files = outputRoot.listFiles()!![0].listFiles()!![0].listFiles()!!
        files.filter { it.name == "output.json" }.let {
            assertEquals(1, it.size)
            assertFalse(it[0]!!.readText().contains("\"error\""))
        }
    }

    // TODO with cache: If a script is ran in *another* pipeline with the same parameters, we should be able to listen to it!

}