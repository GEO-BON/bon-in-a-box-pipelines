package org.geobon.pipeline

import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.geobon.pipeline.teststeps.ConcatenateStep
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

@ExperimentalCoroutinesApi
internal class StepTest {

    @Test
    fun givenNoInOneOut_whenExecuted_thenInputsAreCalledAndOutputReceivesValue() = runTest {
        val step = ConcatenateStep(mapOf())
        assertNull(step.outputs[ConcatenateStep.STRING]!!.value)

        step.execute()

        assertEquals("", step.outputs[ConcatenateStep.STRING]!!.value)
    }

    @Test
    fun givenTwoInOneOut_whenExecuted_thenInputsAreCalledAndOutputReceivesValue() = runTest {
        val input1 = mockk<Pipe>()
        coEvery { input1.pull() } returns "value1"
        val input2 = mockk<Pipe>()
        coEvery { input2.pull() } returns "value2"
        val step = ConcatenateStep(mapOf("1" to input1, "2" to input2))
        assertNull(step.outputs[ConcatenateStep.STRING]!!.value)

        step.execute()

        coVerify {
            input1.pull()
            input2.pull()
        }
        assertNotNull(step.outputs[ConcatenateStep.STRING])
        assertNotNull(step.outputs[ConcatenateStep.STRING]!!.value)
        assertTrue (step.outputs[ConcatenateStep.STRING]!!.value!!.contains("value1"))
        assertTrue (step.outputs[ConcatenateStep.STRING]!!.value!!.contains("value2"))
    }

}