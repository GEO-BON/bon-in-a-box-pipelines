package org.geobon.pipeline

import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals

internal class RunContextTest {

    @Test
    fun givenSameInputs_whenTheOrderOfEntriesIsDifferent_thenRunIdSame() {
        val someFile = File(RunContext.scriptRoot, "someFile")
        val inputs1 = "{aaa:111, bbb:222}"
        val inputs2 = "{bbb:222, aaa:111}"

        val run1 = RunContext(someFile, inputs1)
        val run2 = RunContext(someFile, inputs2)

        println(run1.runId)
        println(run2.runId)

        assertEquals(run1.runId, run2.runId)
    }

    @Test
    fun givenSameInputs_whenTheOrderOfEntriesIsSame_thenRunIdSame() {
        val someFile = File(RunContext.scriptRoot, "someFile")
        val inputs1 = "{aaa:111, bbb:222}"
        val inputs2 = "{aaa:111, bbb:222}"

        val run1 = RunContext(someFile, inputs1)
        val run2 = RunContext(someFile, inputs2)

        assertEquals(run1.runId, run2.runId)
    }

    @Test
    fun givenDifferentInputs_whenTheOrderOfEntriesIsDifferent_thenRunIdDifferent() {
        val someFile = File(RunContext.scriptRoot, "someFile")
        val inputs1 = "{aaa:111, bbb:222}"
        val inputs2 = "{bbb:222, aaa:123}"

        val run1 = RunContext(someFile, inputs1)
        val run2 = RunContext(someFile, inputs2)

        assertNotEquals(run1.runId, run2.runId)
    }

    @Test
    fun givenDifferentInputs_whenTheOrderOfEntriesIsSame_thenRunIdDifferent() {
        val someFile = File(RunContext.scriptRoot, "someFile")
        val inputs1 = "{aaa:111, bbb:222}"
        val inputs2 = "{aaa:123, bbb:222}"

        val run1 = RunContext(someFile, inputs1)
        val run2 = RunContext(someFile, inputs2)

        assertNotEquals(run1.runId, run2.runId)
    }
}