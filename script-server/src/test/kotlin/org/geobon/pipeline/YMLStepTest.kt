package org.geobon.pipeline

import io.mockk.every
import io.mockk.mockk
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import kotlin.test.assertEquals
import kotlin.test.assertNotNull

private class ResourceYml(resourcePath: String, inputs: Map<String, Pipe> = mapOf()) :
    YMLStep(yamlString = ResourceYml::class.java.classLoader.getResource(resourcePath)!!.readText(), inputs = inputs) {
    override suspend fun execute(resolvedInputs: Map<String, String>): Map<String, String> {
        throw Exception("this is in YMLStep, should not be tested")
    }
}

internal class YMLStepTest {
    @Test
    fun givenNoInOneOut_whenConstructed_thenExpectedOutputsIsFound() {
        val step = ResourceYml("scripts/0in1out.yml")
        assertNotNull(step.outputs["randomness"])
        assertEquals("int", step.outputs["randomness"]!!.type)
    }

    @Test
    fun givenOneInOneOut_whenBadNumberOfInputsProvided_thenExceptionIsThrown() {
        // Should throw : no input!
        assertThrows<AssertionError> { ResourceYml("scripts/1in1out.yml") }

        // Should throw : too many inputs!
        val correctInput = mockk<Pipe>()
        every { correctInput.type } returns "int"
        val badInput = mockk<Pipe>()
        every { badInput.type } returns "text/plain"
        assertThrows<AssertionError> { ResourceYml("scripts/1in1out.yml", mapOf(
            "some_int" to correctInput,
            "oups" to badInput
        )) }
    }

    @Test
    fun givenOneInOneOut_whenBadTypeOfInputsProvided_thenExceptionIsThrown() {
        val badInput = mockk<Pipe>()
        every { badInput.type } returns "text/plain"
        assertThrows<AssertionError> { ResourceYml("scripts/1in1out.yml", mapOf("some_int" to badInput)) }
    }

    @Test
    fun givenOneInOneOut_whenInputKeyNotFound_thenExceptionIsThrown() {
        val typoInput = mockk<Pipe>()
        every { typoInput.type } returns "int"
        assertThrows<AssertionError> { ResourceYml("scripts/1in1out.yml", mapOf("some_intt" to typoInput)) }
    }

    @Test
    fun givenOneInOneOut_whenConstructed_thenExpectedIOIsFound() {
        val correctInput = mockk<Pipe>()
        every { correctInput.type } returns "int"
        val step = ResourceYml("scripts/1in1out.yml", mapOf("some_int" to correctInput))
        assertNotNull(step.outputs["number"])
        assertEquals("int", step.outputs["number"]!!.type)
    }

    @Test
    fun givenOneInTwoOut_whenConstructed_thenExpectedIOIsFound() {
        val correctInput = mockk<Pipe>()
        every { correctInput.type } returns "int"
        val step = ResourceYml("scripts/1in2out.yml", mapOf("some_int" to correctInput))

        assertNotNull(step.outputs["number"])
        assertEquals("int", step.outputs["number"]!!.type)

        assertNotNull(step.outputs["tell_me"])
        assertEquals("text/plain", step.outputs["tell_me"]!!.type)
    }
}