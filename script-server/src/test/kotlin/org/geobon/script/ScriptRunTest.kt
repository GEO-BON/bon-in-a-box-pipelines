package org.geobon.script

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
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
        assertTrue(File(System.getenv("OUTPUT_LOCATION")).deleteRecursively())
    }


    @Test
    fun `given script has been run previously_when running again_then cache is used`() = runTest {
        val run1 = ScriptRun(File(scriptRoot, "1in1out.py"), """{"some_int":5}""")
        run1.execute()
        assertNotNull(run1.results["increment"], "increment key not found in ${run1.results}")
        assertEquals(6.0, run1.results["increment"]!!)
        val run1Time = run1.resultFile.lastModified()

        val run2 = ScriptRun(File(scriptRoot, "1in1out.py"), """{"some_int":5}""")
        run2.execute()
        assertNotNull(run2.results["increment"], "increment key not found in ${run2.results}")
        assertEquals(6.0, run2.results["increment"]!!)
        val run2Time = run2.resultFile.lastModified()

        assertEquals(run1Time, run2Time)
    }

    @Test
    fun `given script has been run previously_when running with different parameters_then script ran again`() = runTest {
        val run1 = ScriptRun(File(scriptRoot, "1in1out.py"), """{"some_int":5}""")
        run1.execute()
        assertNotNull(run1.results["increment"], "increment key not found in ${run1.results}")
        assertEquals(6.0, run1.results["increment"]!!)
        val run1Time = run1.resultFile.lastModified()

        val run2 = ScriptRun(File(scriptRoot, "1in1out.py"), """{"some_int":10}""")
        run2.execute()
        assertNotNull(run2.results["increment"], "increment key not found in ${run2.results}")
        assertEquals(11.0, run2.results["increment"]!!)
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
        assertEquals(6.0, run1.results["increment"]!!)
        val run1Time = run1.resultFile.lastModified()

        scriptFile.setLastModified(currentTimeMillis())
        assertNotEquals(scriptTime1, scriptFile.lastModified())

        val run2 = ScriptRun(scriptFile, """{"some_int":5}""")
        run2.execute()
        assertNotNull(run2.results["increment"], "increment key not found in ${run2.results}")
        assertEquals(6.0, run2.results["increment"]!!)
        val run2Time = run2.resultFile.lastModified()

        assertNotEquals(run1Time, run2Time)
    }

    @Test
    fun `given many outputs produced_when scripts completes_only final outputs are kept`() = runTest {

    }
}
