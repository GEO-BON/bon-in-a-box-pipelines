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
            "identified_layers" to AggregatePipe(listOf(
                AssignId(mutableMapOf(
                    "id" to ConstantPipe("text", "first"),
                    "layer" to RecordPipe("1.tiff", finishLine, type = "image/tiff;application=geotiff")
                )).outputs["identified_layer"]!!,
                AssignId(mutableMapOf(
                    "id" to ConstantPipe("text", "second"),
                    "layer" to RecordPipe("2.tiff", finishLine, type = "image/tiff;application=geotiff")
                )).outputs["identified_layer"]!!,
                AssignId(mutableMapOf(
                    "id" to ConstantPipe("text", "third"),
                    "layer" to RecordPipe("3.tiff", finishLine, type = "image/tiff;application=geotiff")
                )).outputs["identified_layer"]!!
            ))
        ))
    }

    @AfterEach
    fun removeOutputFolder() {
        assertTrue(outputRoot.deleteRecursively())
    }


    @Test
    fun whenPullingAllLayer_thenAllLayersPulled() = runTest {
        step.inputs["with_ids"] = ConstantPipe("text", """
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
        """.trimIndent(), step.outputs["with_layers"]!!.pull())

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