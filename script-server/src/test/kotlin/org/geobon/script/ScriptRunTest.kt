package org.geobon.script

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.geobon.pipeline.RunContext.Companion.scriptRoot
import org.geobon.pipeline.outputRoot
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import java.io.File
import java.lang.System.currentTimeMillis

@ExperimentalCoroutinesApi
internal class ScriptRunTest {

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
    fun `given script has been run previously_when running again_then cache is used`() = runTest {
        val run1 = ScriptRun(File(scriptRoot, "1in1out.py"), """{"some_int":5}""")
        run1.execute()
        assertNotNull(run1.results["increment"], "increment key not found in ${run1.results}")
        assertEquals(6, run1.results["increment"]!!)
        val run1Time = run1.resultFile.lastModified()

        val run2 = ScriptRun(File(scriptRoot, "1in1out.py"), """{"some_int":5}""")
        run2.execute()
        assertNotNull(run2.results["increment"], "increment key not found in ${run2.results}")
        assertEquals(6, run2.results["increment"]!!)
        val run2Time = run2.resultFile.lastModified()

        assertEquals(run1Time, run2Time)
    }

    @Test
    fun `given script has been run previously_when running with different parameters_then script ran again`() = runTest {
        val run1 = ScriptRun(File(scriptRoot, "1in1out.py"), """{"some_int":5}""")
        run1.execute()
        assertNotNull(run1.results["increment"], "increment key not found in ${run1.results}")
        assertEquals(6, run1.results["increment"]!!)
        val run1Time = run1.resultFile.lastModified()

        val run2 = ScriptRun(File(scriptRoot, "1in1out.py"), """{"some_int":10}""")
        run2.execute()
        assertNotNull(run2.results["increment"], "increment key not found in ${run2.results}")
        assertEquals(11, run2.results["increment"]!!)
        val run2Time = run2.resultFile.lastModified()

        assertNotEquals(run1Time, run2Time)
    }

    @Test
    fun `given script has been modified since previous run_when ran with same parameters_then script ran again`() = runTest {
        val scriptFile = File(scriptRoot, "1in1out.py")
        scriptFile.setLastModified(currentTimeMillis())
        val scriptTime1 = scriptFile.lastModified()

        val run1 = ScriptRun(scriptFile, """{"some_int":5}""")
        run1.execute()
        assertNotNull(run1.results["increment"], "increment key not found in ${run1.results}")
        assertEquals(6, run1.results["increment"]!!)
        val run1Time = run1.resultFile.lastModified()

        scriptFile.setLastModified(currentTimeMillis())
        assertNotEquals(scriptTime1, scriptFile.lastModified())

        val run2 = ScriptRun(scriptFile, """{"some_int":5}""")
        run2.execute()
        assertNotNull(run2.results["increment"], "increment key not found in ${run2.results}")
        assertEquals(6, run2.results["increment"]!!)
        val run2Time = run2.resultFile.lastModified()

        assertNotEquals(run1Time, run2Time)
    }

    @Test
    fun `given cache removed for modified script_when other results existed_then all cache removed`() = runTest {
        val scriptFile = File(scriptRoot, "1in1out.py")
        scriptFile.setLastModified(currentTimeMillis())

        ScriptRun(scriptFile, """{"some_int":5}""").execute()
        ScriptRun(scriptFile, """{"some_int":6}""").execute()

        // We expect two folder in the cache
        assertEquals(2, outputRoot.listFiles()!![0].listFiles()!!.size)

        scriptFile.setLastModified(currentTimeMillis())
        ScriptRun(scriptFile, """{"some_int":5}""").execute()

        // We expect cache was deleted and only one folder is left
        assertEquals(1, outputRoot.listFiles()!![0].listFiles()!!.size)
    }

    @Test
    fun `given input has changed_when scripts executed_then cache discarded`() = runTest {
        val scriptFile = File(scriptRoot, "checkFile.py")

        // First run
        val inputFile = File(outputRoot, "someinputfile.csv")
        inputFile.createNewFile()
        val run1Time = ScriptRun(scriptFile, """{"file":"${inputFile.path}"}""").let {
            it.execute()
            it.resultFile.lastModified()
        }

        // Second run, input has changed
        inputFile.setLastModified(currentTimeMillis())
        val run2Time = ScriptRun(scriptFile, """{"file":"${inputFile.path}"}""").let {
            it.execute()
            it.resultFile.lastModified()
        }

        // Cache should have been bypassed
        assertNotEquals(run1Time, run2Time)
    }

    @Test
    fun `given input missing_when scripts executed_then cache discarded`() = runTest {
        val scriptFile = File(scriptRoot, "checkFile.py")

        // First run
        val inputFile = File(outputRoot, "someinputfile.csv")
        inputFile.createNewFile()
        val run1Time = ScriptRun(scriptFile, """{"file":"${inputFile.path}"}""").let {
            it.execute()
            it.resultFile.lastModified()
        }

        // Second run, input missing
        inputFile.delete()
        val run2Time = ScriptRun(scriptFile, """{"file":"${inputFile.path}"}""").let {
            it.execute()
            it.resultFile.lastModified()
        }

        // Cache should have been bypassed
        assertNotEquals(run1Time, run2Time)
    }

    @Test
    fun `given many outputs produced_when scripts completes_only final outputs are kept`() = runTest {
        // TODO: Do we want this?
    }
}
