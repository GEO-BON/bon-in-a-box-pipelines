package org.geobon.pipeline

import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * Dummy step for testing purpose
 */
class Concatenate(
    inputs: Map<String, Pipe>
) : Step (inputs, mapOf(STRING to Output("text/plain"))) {

    companion object {
        const val STRING = "string_key"
    }

    override suspend fun execute(resolvedInputs: Map<String, String>) : Map<String, String> {
        var resultString  = ""
        resolvedInputs.values.forEach { resultString += it }
        return mapOf(STRING to resultString)
    }
}

@ExperimentalCoroutinesApi
internal class StepTest {

    @Test
    fun givenNoInOneOut_whenExecuted_thenInputsAreCalledAndOutputReceivesValue() = runTest {
        val step = Concatenate(mapOf())
        assertNull(step.outputs[Concatenate.STRING]!!.value)

        step.execute()

        assertEquals("", step.outputs[Concatenate.STRING]!!.value)
    }

    @Test
    fun givenTwoInOneOut_whenExecuted_thenInputsAreCalledAndOutputReceivesValue() = runTest {
        val input1 = mockk<Pipe>()
        coEvery { input1.pull() } returns "value1"
        val input2 = mockk<Pipe>()
        coEvery { input2.pull() } returns "value2"
        val step = Concatenate(mapOf("1" to input1, "2" to input2))
        assertNull(step.outputs[Concatenate.STRING]!!.value)

        step.execute()

        coVerify {
            input1.pull()
            input2.pull()
        }
        assertNotNull(step.outputs[Concatenate.STRING])
        assertNotNull(step.outputs[Concatenate.STRING]!!.value)
        assertTrue (step.outputs[Concatenate.STRING]!!.value!!.contains("value1"))
        assertTrue (step.outputs[Concatenate.STRING]!!.value!!.contains("value2"))
    }

}