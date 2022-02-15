package org.geobon.pipeline

import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
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

    override fun execute(resolvedInputs: Map<String, String>) : Map<String, String> {
        var resultString  = ""
        resolvedInputs.values.forEach { resultString += it }
        return mapOf(STRING to resultString)
    }
}

internal class StepTest {

    @Test
    fun givenNoInOneOut_whenExecuted_thenInputsAreCalledAndOutputReceivesValue() {
        val step = Concatenate(mapOf())
        assertNull(step.outputs[Concatenate.STRING]!!.value)

        step.execute()

        assertEquals("", step.outputs[Concatenate.STRING]!!.value)
    }

    @Test
    fun givenTwoInOneOut_whenExecuted_thenInputsAreCalledAndOutputReceivesValue() {
        val input1 = mockk<Pipe>()
        every { input1.pull() } returns "value1"
        val input2 = mockk<Pipe>()
        every { input2.pull() } returns "value2"
        val step = Concatenate(mapOf("1" to input1, "2" to input2))

        assertNull(step.outputs[Concatenate.STRING]!!.value)

        step.execute()

        verify {
            input1.pull()
            input2.pull()
        }
        assertNotNull(step.outputs[Concatenate.STRING])
        assertNotNull(step.outputs[Concatenate.STRING]!!.value)
        assertTrue (step.outputs[Concatenate.STRING]!!.value!!.contains("value1"))
        assertTrue (step.outputs[Concatenate.STRING]!!.value!!.contains("value2"))
    }

}