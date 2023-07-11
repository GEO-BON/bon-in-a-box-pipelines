package org.geobon.pipeline

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.geobon.pipeline.teststeps.RecordPipe
import org.geobon.utils.withProductionPaths
import org.geobon.utils.withProductionScripts
import org.json.JSONObject
import kotlin.test.*

@ExperimentalCoroutinesApi
internal class PullLayersByIdTest {

    private lateinit var finishLine: MutableList<String>
    private lateinit var step: Step

    @BeforeTest
    fun setup() = withProductionPaths {
        with(outputRoot) {
            assertTrue(!exists())
            mkdirs()
            assertTrue(exists())
        }

        finishLine = mutableListOf()

        step = PullLayersById(StepId("pull", "0"), mutableMapOf(
            PullLayersById.IN_IDENTIFIED_LAYERS to AggregatePipe(listOf(
                AssignId(StepId("assign", "1"), mutableMapOf(
                    AssignId.IN_ID to ConstantPipe("text", "first"),
                    AssignId.IN_LAYER to RecordPipe("1.tiff", finishLine, type = "image/tiff;application=geotiff")
                )).outputs[AssignId.OUT_IDENTIFIED_LAYER]!!,
                AssignId(StepId("assign", "2"), mutableMapOf(
                    AssignId.IN_ID to ConstantPipe("text", "second"),
                    AssignId.IN_LAYER to RecordPipe("2.tiff", finishLine, type = "image/tiff;application=geotiff")
                )).outputs[AssignId.OUT_IDENTIFIED_LAYER]!!,
                AssignId(StepId("assign", "3"), mutableMapOf(
                    AssignId.IN_ID to ConstantPipe("text", "third"),
                    AssignId.IN_LAYER to RecordPipe("3.tiff", finishLine, type = "image/tiff;application=geotiff")
                )).outputs[AssignId.OUT_IDENTIFIED_LAYER]!!
            ))
        ))
    }

    @AfterTest
    fun removeOutputFolder() {
        assertTrue(outputRoot.deleteRecursively())
    }


    @Test
    fun whenPulling_thenTypesAreRespected() = runTest {
        withProductionPaths {
            val identifiedLayers = step.inputs[PullLayersById.IN_IDENTIFIED_LAYERS]!!
            assertTrue(identifiedLayers is AggregatePipe, "Not an AggregatePipe, found a ${identifiedLayers.javaClass.name}")

            val pulledList = identifiedLayers.pull()
            if (pulledList is List<*>) {
                assertTrue(pulledList.size > 0, "List is empty")
                pulledList.forEach { pulled ->
                    assertTrue(pulled is JSONObject, "Not a JSONObject, found a ${pulled?.javaClass?.name}")
                }
            } else {
                fail("Got a ${pulledList.javaClass.name} which is not a list")
            }
        }
    }

    @Test
    fun whenPullingConditionally_thenTypesAreRespected() = runTest {
        withProductionPaths {
            val singlePullIf = AssignId(StepId("assign", "0"), mutableMapOf(
                AssignId.IN_ID to ConstantPipe("text", "first"),
                AssignId.IN_LAYER to RecordPipe("1.tiff", finishLine, type = "image/tiff;application=geotiff")
            )).outputs[AssignId.OUT_IDENTIFIED_LAYER]!!.pullIf { true }
            assertTrue(singlePullIf is JSONObject, "Single: Not a JSONObject, found a ${singlePullIf?.javaClass?.name}")

            val identifiedLayers = step.inputs[PullLayersById.IN_IDENTIFIED_LAYERS]!!
            assertTrue(identifiedLayers is AggregatePipe, "Not an AggregatePipe, found a ${identifiedLayers.javaClass.name}")

            val pulledList = identifiedLayers.pullIf { true }
            if (pulledList is List<*>) {
                assertTrue(pulledList.size > 0, "List is empty")
                pulledList.forEach { pulled ->
                    assertTrue(pulled is JSONObject, "In list: Not a JSONObject, found a ${pulled?.javaClass?.name}")
                }
            } else {
                fail("Got a ${pulledList?.javaClass?.name} which is not a list")
            }
        }
    }

    @Test
    fun whenPullingAllLayer_thenAllLayersPulled() = runTest {
        withProductionPaths {
            step.inputs[PullLayersById.IN_WITH_IDS] = ConstantPipe("text", """
                layer, current, change
                first, 0.2, 0.5
                second, 0.5, 0.2
                third, 0.3, 0.3
                """.trimIndent()
            )
            step.validateGraph().let {
                assertTrue(it.isEmpty(), it)
            }

            step.execute()

            assertEquals("""
                layer, current, change
                1.tiff, 0.2, 0.5
                2.tiff, 0.5, 0.2
                3.tiff, 0.3, 0.3
                """.trimIndent(), step.outputs[PullLayersById.OUT_WITH_LAYERS]!!.pull()
            )

            assertContains(finishLine, "1.tiff")
            assertContains(finishLine, "2.tiff")
            assertContains(finishLine, "3.tiff")
        }
    }

    @Test
    fun whenPullingSomeLayer_thenOnlyTheseArePulled() = runTest {
        withProductionPaths {
            step.inputs[PullLayersById.IN_WITH_IDS] = ConstantPipe("text", """
                layer, current, change
                second, 0.5, 0.2
                third, 0.5, 0.8
                """.trimIndent()
            )
            step.validateGraph().let {
                assertTrue(it.isEmpty(), it)
            }

            step.execute()

            assertEquals("""
                layer, current, change
                2.tiff, 0.5, 0.2
                3.tiff, 0.5, 0.8
                """.trimIndent(), step.outputs[PullLayersById.OUT_WITH_LAYERS]!!.pull()
            )

            assertFalse(finishLine.contains("1.tiff"))
            assertContains(finishLine, "2.tiff")
            assertContains(finishLine, "3.tiff")
        }
    }


    @Test
    fun whenPullingNoLayers_thenMatrixUnchanged() = runTest {
        withProductionPaths {
            val matrix = """
               layer, current, change
               invalidId, 0.5, 0.2
               invalidId, 0.5, 0.8
               """.trimIndent()
            step.inputs[PullLayersById.IN_WITH_IDS] = ConstantPipe("text", matrix)
            step.validateGraph().let {
                assertTrue(it.isEmpty(), it)
            }

            step.execute()
            
            assertEquals(matrix, step.outputs[PullLayersById.OUT_WITH_LAYERS]!!.pull())
            assertTrue(finishLine.isEmpty())
        }
    }

    @Test
    fun givenObjectWithMissingParam_whenExecuted_thenErrorMessageSent() = runTest {
        withProductionPaths {
            step.inputs[PullLayersById.IN_IDENTIFIED_LAYERS] = AggregatePipe(listOf(
                step.inputs[PullLayersById.IN_IDENTIFIED_LAYERS]!!,
                ConstantPipe("object", JSONObject(
                    """{id:"second"}"""
                ))
            ))

            // Normal input map
            step.inputs[PullLayersById.IN_WITH_IDS] = ConstantPipe("text", """
                    layer, current, change
                    first, 0.2, 0.5
                    second, 0.5, 0.2
                    third, 0.3, 0.3
                    fourth, 0, 0
                    """.trimIndent()
            )

            assertFailsWith<RuntimeException> {
                step.execute()
            }
        }
    }

    @Test
    fun `given a pipeline with PullLayersById_when ran_then replaces the expected layer`() = runTest {
        withProductionScripts {
            val pipeline = RootPipeline("pullLayersByIdTest.json",
            """{
                "pipeline>PullLayersById.yml@9|with_ids": "layer, current, change\nfirstId, 0.2, 0.5\nGFW170E, 0.5, 0.2\nthirdId, 0.3, 0.3\n"
            }""".trimIndent())

            pipeline.pullFinalOutputs()

            val result = pipeline.getPipelineOutputs()[0].pull().toString()
            assertFalse(result.contains("https://object-arbutus.cloud.computecanada.ca/bq-io/io/GFW/lossyear/Hansen_GFC-2020-v1.8_lossyear_80N_180W.tif"))
            assertFalse(result.contains("https://object-arbutus.cloud.computecanada.ca/bq-io/io/GFW/lossyear/Hansen_GFC-2020-v1.8_lossyear_80N_170W.tif"))
            assertTrue(result.contains("https://object-arbutus.cloud.computecanada.ca/bq-io/io/GFW/lossyear/Hansen_GFC-2020-v1.8_lossyear_80N_170E.tif"))
        }
    }
}