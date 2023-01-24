package org.geobon.pipeline

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.geobon.pipeline.teststeps.ConcatenateStep
import org.geobon.pipeline.teststeps.EchoStep
import org.geobon.pipeline.teststeps.EchoStep.Companion.ECHO
import org.geobon.pipeline.teststeps.EchoStep.Companion.SOUND
import org.geobon.utils.runReliableTest
import kotlin.test.*

@ExperimentalCoroutinesApi
internal class StepsPullTest {

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
    fun `given pipeline with single flow_when pulling final step_then all nodes are pulled`() = runTest {
        // Note: in non-test code: surround whole block with try/catch, there are so many !! in there
        val step1 = ScriptStep("0in1out.yml") // 234
        val step2 = ScriptStep("1in1out.yml", mutableMapOf("some_int" to step1.outputs["randomness"]!!)) // 235
        val finalStep = ScriptStep("1in1out.yml", mutableMapOf("some_int" to step2.outputs["increment"]!!)) // 236

        assertEquals(236, finalStep.outputs["increment"]!!.pull())
    }

    @Test
    fun `given pipeline with branches_when pulling final step_then both branches are executed`() = runTest {
        // Note: in non-test code: surround whole block with try/catch, there are so many !! in there
        val step1 = ScriptStep("0in1out.yml") // 234
        val step2 = ScriptStep("1in2out.yml", mutableMapOf("some_int" to step1.outputs["randomness"]!!)) // 235, "What a wonderful "

        val intBranch = ScriptStep("1in1out.yml", mutableMapOf("some_int" to step2.outputs["increment"]!!)) // 236
        val stringBranch = ConcatenateStep(mutableMapOf(
            "1" to step2.outputs["tell_me"]!!,
            "2" to ConstantPipe("text/plain", "world!"))) // "What a wonderful world!" or "world!What a wonderful "

        val finalStep = ConcatenateStep(mutableMapOf(
            "1" to intBranch.outputs["increment"]!!,
            "2" to stringBranch.outputs[ConcatenateStep.STRING]!!))

        val result:String = finalStep.outputs[ConcatenateStep.STRING]!!.pull().toString()
        assertTrue(result.contains("What a wonderful "))
        assertTrue(result.contains("world!"))
        assertTrue(result.contains("236"))
    }

    @Test
    fun `given pipeline dead branch_when pulling final step_then dead branch not executed`() = runTest {
        // Note: in non-test code: surround whole block with try/catch, there are so many !! in there
        val step1 = ScriptStep("0in1out.yml") // 234
        val step2 = ScriptStep("1in2out.yml", mutableMapOf("some_int" to step1.outputs["randomness"]!!)) // 235, "What a wonderful "
        val goodBranch = ScriptStep("1in1out.yml", mutableMapOf("some_int" to step2.outputs["increment"]!!)) // 236
        val deadBranch = ConcatenateStep(mutableMapOf(
            "1" to step2.outputs["tell_me"]!!,
            "2" to ConstantPipe("text/plain", "world!"))) // "What a wonderful world!" or "world!What a wonderful "

        val finalStep = ScriptStep("1in1out.yml", mutableMapOf("some_int" to goodBranch.outputs["increment"]!!)) // 237

        assertEquals(237, finalStep.outputs["increment"]!!.pull())
        assertNull(deadBranch.outputs[ConcatenateStep.STRING]!!.value)
    }

    @Test
    fun `given pipeline_when script fails_then pipeline is halted with exception`() {
        // Note: in non-test code: surround whole block with try/catch, there are so many !! in there
        val step1 = ScriptStep("0in1out.yml") // 234
        val step2 = ScriptStep("1in1out_fail.yml", mutableMapOf("some_int" to step1.outputs["randomness"]!!)) // 235
        val finalStep = ScriptStep("1in1out.yml", mutableMapOf("some_int" to step2.outputs["increment"]!!)) // 236

        try {
            runReliableTest {
                finalStep.outputs["increment"]!!.pull()
                fail("It should have crashed")
            }
        } catch (_:Exception) {
            // Success!
            // println("got: ${ex.message}")
        }

        // Script results left as they were before crash
        assertEquals(234, step1.outputs["randomness"]!!.value)
        assertNull(step2.outputs["increment"]!!.value)
        assertNull(finalStep.outputs["increment"]!!.value)
    }

    @Test
    fun `given single origin and output but multiple branches_when ran_then origin step ran only once`() = runTest {
        val origin = ConstantPipe("text", "Echo!")
        val mainBranch = EchoStep(mutableMapOf(SOUND to origin))
        val branch1 = EchoStep(mutableMapOf(SOUND to mainBranch.outputs[ECHO]!!))
        val branch2 = EchoStep(mutableMapOf(SOUND to mainBranch.outputs[ECHO]!!))
        val merged = ConcatenateStep(mutableMapOf("1" to branch1.outputs[ECHO]!!, "2" to branch2.outputs[ECHO]!!))

        val result = merged.outputs[ConcatenateStep.STRING]!!.pull()

        assertEquals("Echo!Echo!", result)
        assertEquals(1, branch1.executeCount)
        assertEquals(1, branch2.executeCount)
        assertEquals(1, mainBranch.executeCount)
    }

}