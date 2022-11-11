package org.geobon.pipeline

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.geobon.pipeline.teststeps.RecordPipe
import org.geobon.script.outputRoot
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import kotlin.test.assertContains
import kotlin.test.assertFailsWith

@ExperimentalCoroutinesApi
internal class PullLayersByIdTest {

    lateinit var finishLine: MutableList<String>
    lateinit var step: Step

    @BeforeEach
    fun setup() {
        with(outputRoot) {
            assertTrue(!exists())
            mkdirs()
            assertTrue(exists())
        }

        finishLine = mutableListOf()

        step = PullLayersById(mutableMapOf(
            PullLayersById.IN_IDENTIFIED_LAYERS to AggregatePipe(listOf(
                AssignId(mutableMapOf(
                    AssignId.IN_ID to ConstantPipe("text", "first"),
                    AssignId.IN_LAYER to RecordPipe("1.tiff", finishLine, type = "image/tiff;application=geotiff")
                )).outputs[AssignId.OUT_IDENTIFIED_LAYER]!!,
                AssignId(mutableMapOf(
                    AssignId.IN_ID to ConstantPipe("text", "second"),
                    AssignId.IN_LAYER to RecordPipe("2.tiff", finishLine, type = "image/tiff;application=geotiff")
                )).outputs[AssignId.OUT_IDENTIFIED_LAYER]!!,
                AssignId(mutableMapOf(
                    AssignId.IN_ID to ConstantPipe("text", "third"),
                    AssignId.IN_LAYER to RecordPipe("3.tiff", finishLine, type = "image/tiff;application=geotiff")
                )).outputs[AssignId.OUT_IDENTIFIED_LAYER]!!
            ))
        ))
    }

    @AfterEach
    fun removeOutputFolder() {
        assertTrue(outputRoot.deleteRecursively())
    }


    @Test
    fun whenPullingAllLayer_thenAllLayersPulled() = runTest {
        step.inputs[PullLayersById.IN_WITH_IDS] = ConstantPipe("text", """
            layer, current, change
            first, 0.2, 0.5
            second, 0.5, 0.2
            third, 0.3, 0.3
        """.trimIndent())
        step.validateGraph().let {
            assertTrue(it.isEmpty(), it)
        }

        step.execute()

        assertEquals("""
            layer, current, change
            1.tiff, 0.2, 0.5
            2.tiff, 0.5, 0.2
            3.tiff, 0.3, 0.3
        """.trimIndent(), step.outputs[PullLayersById.OUT_WITH_LAYERS]!!.pull())

        assertContains(finishLine, "1.tiff")
        assertContains(finishLine, "2.tiff")
        assertContains(finishLine, "3.tiff")
    }

//    @Test
//    fun whenPullingSomeLayer_thenOnlyTheseArePulled() = runTest {
//        step.inputs["with_ids"] = ConstantPipe("text", """
//            layer, current, change
//            second, 0.5, 0.2
//            third, 0.5, 0.8
//        """.trimIndent())
//        step.validateGraph().let {
//            assertTrue(it.isEmpty(), it)
//        }
//
//        step.execute()
//
//        assertEquals("""
//            layer, current, change
//            2.tiff, 0.5, 0.2
//            3.tiff, 0.5, 0.8
//        """.trimIndent(), step.outputs["with_layers"]!!.pull())
//
//        assertFalse(finishLine.contains("1.tiff"))
//        assertContains(finishLine, "2.tiff")
//        assertContains(finishLine, "3.tiff")
//    }
//
//
//    @Test
//    fun whenPullingNoLayers_thenErrorThrown() = runTest {
//        step.inputs["with_ids"] = ConstantPipe("text", """
//            layer, current, change
//            invalidId, 0.5, 0.2
//            invalidId, 0.5, 0.8
//        """.trimIndent())
//        step.validateGraph().let {
//            assertTrue(it.isEmpty(), it)
//        }
//
//        assertThrows{
//            step.execute()
//        }
//
//
//        assertEquals("""
//            layer, current, change
//            2.tiff, 0.5, 0.2
//            3.tiff, 0.5, 0.8
//        """.trimIndent(), step.outputs["with_layers"]!!.pull())
//
//        assertTrue(finishLine.isEmpty())
//    }
}