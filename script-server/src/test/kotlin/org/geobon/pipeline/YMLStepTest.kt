package org.geobon.pipeline

import io.mockk.every
import io.mockk.mockk
import org.junit.jupiter.api.Test
import kotlin.test.assertTrue
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull

private class ResourceYml(resourcePath: String, inputs: Map<String, Pipe> = mapOf()) :
    YMLStep(yamlString = ResourceYml::class.java.classLoader.getResource(resourcePath)!!.readText(), inputs = inputs) {
    override suspend fun execute(resolvedInputs: Map<String, Any>): Map<String, Any> {
        throw Exception("this is in YMLStep, should not be tested")
    }
}

internal class YMLStepTest {
    @Test
    fun givenNoInOneOut_whenConstructed_thenExpectedOutputsIsFound() {
        val step = ResourceYml("scripts/0in1out.yml")
        assertTrue(step.validateGraph().isEmpty())
        assertNotNull(step.outputs["randomness"])
        assertEquals("int", step.outputs["randomness"]!!.type)
    }

    @Test
    fun givenOneInOneOut_whenBadNumberOfInputsProvided_thenValidationFails() {
        // Should throw : no input!
        var step = ResourceYml("scripts/1in1out.yml")
        assertFalse(step.validateGraph().isEmpty())

        // Should throw : too many inputs!
        val correctInput = mockk<Pipe>()
        every { correctInput.type } returns "int"
        every { correctInput.validateGraph() } returns ""
        val badInput = mockk<Pipe>()
        every { badInput.type } returns "text/plain"
        every { badInput.validateGraph() } returns ""
        step = ResourceYml("scripts/1in1out.yml", mapOf(
            "some_int" to correctInput,
            "oups" to badInput
        ))

        assertFalse(step.validateGraph().isEmpty())
    }

    @Test
    fun givenOneInOneOut_whenBadTypeOfInputsProvided_thenValidationFails() {
        val badInput = mockk<Pipe>()
        every { badInput.type } returns "text/plain"
        every { badInput.validateGraph() } returns ""
        val step = ResourceYml("scripts/1in1out.yml", mapOf("some_int" to badInput))
        assertFalse(step.validateGraph().isEmpty())
    }

    @Test
    fun givenOneInOneOut_whenInputKeyNotFound_thenValidationFails() {
        val typoInput = mockk<Pipe>()
        every { typoInput.type } returns "int"
        every { typoInput.validateGraph() } returns ""
        val step = ResourceYml("scripts/1in1out.yml", mapOf("some_intt" to typoInput))
        assertFalse(step.validateGraph().isEmpty())
    }

    @Test
    fun givenOneInOneOut_whenConstructed_thenExpectedIOIsFound() {
        val correctInput = mockk<Pipe>()
        every { correctInput.type } returns "int"
        every { correctInput.validateGraph() } returns ""
        val step = ResourceYml("scripts/1in1out.yml", mapOf("some_int" to correctInput))
        assertTrue(step.validateGraph().isEmpty())
        assertNotNull(step.outputs["increment"])
        assertEquals("int", step.outputs["increment"]!!.type)
    }

    @Test
    fun givenOneInTwoOut_whenConstructed_thenExpectedIOIsFound() {
        val correctInput = mockk<Pipe>()
        every { correctInput.type } returns "int"
        every { correctInput.validateGraph() } returns ""
        val step = ResourceYml("scripts/1in2out.yml", mapOf("some_int" to correctInput))

        assertTrue(step.validateGraph().isEmpty())
        assertNotNull(step.outputs["increment"])
        assertEquals("int", step.outputs["increment"]!!.type)

        assertNotNull(step.outputs["tell_me"])
        assertEquals("text/plain", step.outputs["tell_me"]!!.type)
    }
}