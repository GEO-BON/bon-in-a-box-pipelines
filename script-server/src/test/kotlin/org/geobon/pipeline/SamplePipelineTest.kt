package org.geobon.pipeline

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.geobon.pipeline.teststeps.ConcatenateStep
import org.geobon.script.outputRoot
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import java.io.File

@ExperimentalCoroutinesApi
internal class SamplePipelineTest {

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
    fun `given pipeline with single flow_when pulling final step_then all nodes are pulled`() = runTest {
        // Note: in non-test code: surround whole block with try/catch, there are so many !! in there
        val step1 = ScriptStep("0in1out.yml") // 234
        val step2 = ScriptStep("1in1out.yml", mapOf("some_int" to step1.outputs["randomness"]!!)) // 235
        val finalStep = ScriptStep("1in1out.yml", mapOf("some_int" to step2.outputs["increment"]!!)) // 236

        assertEquals(236.0, finalStep.outputs["increment"]!!.pull())
    }

    @Test
    fun `given pipeline with branches_when pulling final step_then both branches are executed`() = runTest {
        // Note: in non-test code: surround whole block with try/catch, there are so many !! in there
        val step1 = ScriptStep("0in1out.yml") // 234
        val step2 = ScriptStep("1in2out.yml", mapOf("some_int" to step1.outputs["randomness"]!!)) // 235, "What a wonderful "

        val intBranch = ScriptStep("1in1out.yml", mapOf("some_int" to step2.outputs["increment"]!!)) // 236
        val stringBranch = ConcatenateStep(mapOf(
            "1" to step2.outputs["tell_me"]!!,
            "2" to ConstantPipe("text/plain", "world!"))) // "What a wonderful world!" or "world!What a wonderful "

        val finalStep = ConcatenateStep(mapOf(
            "1" to intBranch.outputs["increment"]!!,
            "2" to stringBranch.outputs[ConcatenateStep.STRING]!!))

        val result:String = finalStep.outputs[ConcatenateStep.STRING]!!.pull().toString()
        assertTrue(result.contains("What a wonderful "))
        assertTrue(result.contains("world!"))
        assertTrue(result.contains("236.0"))
    }

    @Test
    fun `given pipeline dead branch_when pulling final step_then dead branch not executed`() = runTest {
        // Note: in non-test code: surround whole block with try/catch, there are so many !! in there
        val step1 = ScriptStep("0in1out.yml") // 234
        val step2 = ScriptStep("1in2out.yml", mapOf("some_int" to step1.outputs["randomness"]!!)) // 235, "What a wonderful "
        val goodBranch = ScriptStep("1in1out.yml", mapOf("some_int" to step2.outputs["increment"]!!)) // 236
        val deadBranch = ConcatenateStep(mapOf(
            "1" to step2.outputs["tell_me"]!!,
            "2" to ConstantPipe("text/plain", "world!"))) // "What a wonderful world!" or "world!What a wonderful "

        val finalStep = ScriptStep("1in1out.yml", mapOf("some_int" to goodBranch.outputs["increment"]!!)) // 237

        assertEquals(237.0, finalStep.outputs["increment"]!!.pull())
        assertNull(deadBranch.outputs[ConcatenateStep.STRING]!!.value)
    }

}