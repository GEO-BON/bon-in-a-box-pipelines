package org.geobon.pipeline

import kotlin.test.*

internal class IOIdTest {

    @Test
    fun ioIdToStringTest() {
        // Regular script input or output
        assertEquals(
            "myStep@myNodeId|myOutputId",
            IOId(StepId("myStep", "myNodeId"), "myOutputId").toString()
        )

        // Pipeline input
        assertEquals(
            "pipeline@myNodeId",
            IOId(StepId("pipeline", "myNodeId")).toString()
        )

        // Nested pipeline input
        assertEquals(
            "myPipeline@pipelineId|myStep@myNodeId|myOutputId",
            IOId(StepId("myPipeline", "pipelineId"), "myStep@myNodeId|myOutputId").toString()
        )
        assertEquals(
            "myPipeline@pipelineId|myStep@myNodeId|myOutputId",
            IOId(StepId("myPipeline", "pipelineId"), IOId(StepId("myStep", "myNodeId"), "myOutputId")).toString()
        )
    }

    @Test
    fun getScriptTest() {
        assertEquals(
            "script.yml",
            getScript("script.yml@31|output")
        )

        assertEquals(
            "script.yml",
            getScript("pipeline.json@12|pipeline.json@23|script.yml@31|output")
        )
    }

    @Test
    fun getStepIdTest() {
        assertEquals(
            "script.yml@31",
            getStepId("script.yml@31")
        )

        assertEquals(
            "pipeline.json@12",
            getStepId("pipeline.json@12|pipeline.json@23|script.yml@31|output")
        )
    }

    @Test
    fun getStepFileTest() {
        assertEquals(
            "pipeline.json",
            getStepFile("pipeline.json@12|pipeline.json@23|script.yml@31|output")
        )
    }

    @Test
    fun getStepNodeIdTest() {
        assertEquals(
            "12",
            getStepNodeId("pipeline@12")
        )

        assertEquals(
            "12",
            getStepNodeId("pipeline.json@12|pipeline.json@23|script.yml@31|output")
        )
    }

    @Test
    fun getStepOutputTest() {
        assertEquals(
            "pipeline.json@23|script.yml@31|output",
            getStepOutput("pipeline.json@12|pipeline.json@23|script.yml@31|output")
        )
    }

    @Test
    fun getStepInputTest() {
        assertEquals(
            "pipeline.json@23|script.yml@31|input",
            getStepInput("pipeline.json@12|pipeline.json@23|script.yml@31|input")
        )
    }
}