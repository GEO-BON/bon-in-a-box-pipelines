package org.geobon.pipeline

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Test

class EchoStep(private val sound: String) :
    Step(
        outputs = mapOf(
            KEY to Output("text/plain"),
            BAD_KEY to Output("text/plain")
        )
    ) {

    companion object {
        const val KEY = "echo"
        const val BAD_KEY = "no-echo"
    }

    override fun execute(resolvedInputs: Map<String, String>): Map<String, String> {
        return mapOf(KEY to sound)
    }
}

internal class OutputTest {

    @Test
    fun givenConnectedOutput_whenPull_thenStepIsLaunched() {
        val expected = "Bouh!"
        val step = EchoStep(expected)

        assertEquals(expected, step.outputs[EchoStep.KEY]?.pull())
    }

    @Test
    fun givenDisconnectedOutput_whenPull_thenExceptionThrown() {
        val underTest = Output("text/plain")

        assertThrows(Exception::class.java) {
            println(underTest.pull())
        }
    }

    @Test
    fun givenOutputNotFulfilled_whenPull_thenExceptionThrown() {
        val step = EchoStep("Bouh!")

        assertThrows(Exception::class.java) {
            println(step.outputs[EchoStep.BAD_KEY]!!.pull())
        }
    }
}