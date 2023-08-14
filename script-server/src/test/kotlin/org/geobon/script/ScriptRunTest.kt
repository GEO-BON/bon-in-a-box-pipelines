package org.geobon.script

import io.kotest.extensions.system.OverrideMode
import io.kotest.extensions.system.withEnvironment
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.geobon.pipeline.RunContext.Companion.scriptRoot
import org.geobon.pipeline.outputRoot
import java.io.File
import java.lang.System.currentTimeMillis
import kotlin.test.*

@ExperimentalCoroutinesApi
internal class ScriptRunTest {

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
    fun `given script has been run previously_when running again_then cache is used`() = runTest {
        val run1 = ScriptRun(File(scriptRoot, "1in1out.py"), mapOf("some_int" to 5))
        run1.execute()
        assertNotNull(run1.results["increment"], "increment key not found in ${run1.results}")
        assertEquals(6, run1.results["increment"]!!)
        val run1Time = run1.resultFile.lastModified()

        val run2 = ScriptRun(File(scriptRoot, "1in1out.py"), mapOf("some_int" to 5))
        run2.execute()
        assertNotNull(run2.results["increment"], "increment key not found in ${run2.results}")
        assertEquals(6, run2.results["increment"]!!)
        val run2Time = run2.resultFile.lastModified()

        assertEquals(run1Time, run2Time)
    }

    @Test
    fun `given script has been run previously_when running with different parameters_then script ran again`() = runTest {
        val run1 = ScriptRun(File(scriptRoot, "1in1out.py"), mapOf("some_int" to 5))
        run1.execute()
        assertNotNull(run1.results["increment"], "increment key not found in ${run1.results}")
        assertEquals(6, run1.results["increment"]!!)
        val run1Time = run1.resultFile.lastModified()

        val run2 = ScriptRun(File(scriptRoot, "1in1out.py"), mapOf("some_int" to 10))
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

        val run1 = ScriptRun(scriptFile, mapOf("some_int" to 5))
        run1.execute()
        assertNotNull(run1.results["increment"], "increment key not found in ${run1.results}")
        assertEquals(6, run1.results["increment"]!!)
        val run1Time = run1.resultFile.lastModified()

        scriptFile.setLastModified(currentTimeMillis())
        assertNotEquals(scriptTime1, scriptFile.lastModified())

        val run2 = ScriptRun(scriptFile, mapOf("some_int" to 5))
        run2.execute()
        assertNotNull(run2.results["increment"], "increment key not found in ${run2.results}")
        assertEquals(6, run2.results["increment"]!!)
        val run2Time = run2.resultFile.lastModified()

        assertNotEquals(run1Time, run2Time)
    }

    @Test
    fun `given other results existed_when cache cleaned with option full_then all cache removed`() = runTest {
        val scriptFile = File(scriptRoot, "1in1out.py")
        scriptFile.setLastModified(currentTimeMillis())

        ScriptRun(scriptFile, mapOf("some_int" to 5)).execute()
        ScriptRun(scriptFile, mapOf("some_int" to 6)).execute()

        // We expect two folder in the cache
        assertEquals(2, outputRoot.listFiles()!![0].listFiles()!!.size)

        scriptFile.setLastModified(currentTimeMillis())
        ScriptRun(scriptFile, mapOf("some_int" to 5)).execute()

        // We expect cache was deleted and only one folder is left
        assertEquals(1, outputRoot.listFiles()!![0].listFiles()!!.size)
    }

    @Test
    fun `given other results existed_when cache cleaned with option partial_then all cache removed`() = runTest {
        withEnvironment("SCRIPT_SERVER_CACHE_CLEANER", "partial", OverrideMode.SetOrOverride) {
            val scriptFile = File(scriptRoot, "1in1out.py")
            scriptFile.setLastModified(currentTimeMillis())

            val val5Run1 = ScriptRun(scriptFile, mapOf("some_int" to 5))
            val5Run1.execute()
            val val5Run1LastModified = val5Run1.resultFile.lastModified()
            val val6Run1 = ScriptRun(scriptFile, mapOf("some_int" to 6))
            val6Run1.execute()

            // We expect two folder in the cache
            assertEquals(2, outputRoot.listFiles()!![0].listFiles()!!.size)

            scriptFile.setLastModified(currentTimeMillis())
            val val5Run2 = ScriptRun(scriptFile, mapOf("some_int" to 5))
            val5Run2.execute()

            // We still expect two folders in the cache
            assertEquals(2, outputRoot.listFiles()!![0].listFiles()!!.size)
            assertTrue(val5Run2.resultFile.exists())
            assertTrue(val6Run1.resultFile.exists())
            assertEquals(val5Run1.resultFile, val5Run2.resultFile)

            // The result has been overriden
            assertTrue(val5Run1LastModified < val5Run2.resultFile.lastModified())
        }
    }

    @Test
    fun `given unset cache clean option_when ran_then cache cleaned with full option`() = runTest {
        withEnvironment("SCRIPT_SERVER_CACHE_CLEANER", "", OverrideMode.SetOrOverride) {
            `given other results existed_when cache cleaned with option full_then all cache removed`()
        }
    }

    @Test
    fun `given input has changed_when scripts executed_then cache discarded`() = runTest {
        val scriptFile = File(scriptRoot, "checkFile.py")

        // First run
        val inputFile = File(outputRoot, "someinputfile.csv")
        inputFile.createNewFile()
        val run1Time = ScriptRun(scriptFile, mapOf("file" to inputFile.path)).let {
            it.execute()
            it.resultFile.lastModified()
        }

        // Second run, input has changed
        inputFile.setLastModified(currentTimeMillis())
        val run2Time = ScriptRun(scriptFile, mapOf("file" to inputFile.path)).let {
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
        val run1Time = ScriptRun(scriptFile, mapOf("file" to inputFile.path)).let {
            it.execute()
            it.resultFile.lastModified()
        }

        // Second run, input missing
        inputFile.delete()
        val run2Time = ScriptRun(scriptFile, mapOf("file" to inputFile.path)).let {
            it.execute()
            it.resultFile.lastModified()
        }

        // Cache should have been bypassed
        assertNotEquals(run1Time, run2Time)
    }

}
