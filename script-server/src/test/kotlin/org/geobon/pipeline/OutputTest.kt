package org.geobon.pipeline

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.geobon.pipeline.teststeps.EchoStep
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import kotlin.test.assertEquals

@ExperimentalCoroutinesApi
internal class OutputTest {

    @Test
    fun givenConnectedOutput_whenPull_thenStepIsLaunched() = runTest {
        val expected = "Bouh!"
        val step = EchoStep(expected)

        assertEquals(expected, step.outputs[EchoStep.ECHO]?.pull())
    }

    @Test
    fun givenDisconnectedOutput_whenPull_thenExceptionThrown() = runTest {
        val underTest = Output("text/plain")

        assertThrows<Exception> {
            println(underTest.pull())
        }
    }

    @Test
    fun givenOutputNotFulfilled_whenPull_thenExceptionThrown() = runTest {
        val step = EchoStep("Bouh!")

        assertThrows<Exception> {
            println(step.outputs[EchoStep.NO_ECHO]!!.pull())
        }
    }
}