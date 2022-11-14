package org.geobon.pipeline.teststeps

import kotlinx.coroutines.delay
import org.geobon.pipeline.ConstantPipe
import org.geobon.pipeline.Step

/**
 * Records the order in which pull results crossed the finish line.
 */
class RecordPipe(
    value: String,
    private val finishLine: MutableList<String>?,
    private val delay: Long = 0,
    type: String = "text/plain"
) :
    ConstantPipe(type, value) {

    override suspend fun pull(): Any {
        delay(delay)

        return super.pull()
            .also { finishLine?.add(it.toString()) }
    }

    override suspend fun pullIf(condition: (step: Step) -> Boolean): Any {
        return pull()
    }
}