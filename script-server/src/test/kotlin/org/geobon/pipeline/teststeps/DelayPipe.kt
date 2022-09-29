package org.geobon.pipeline.teststeps

import kotlinx.coroutines.delay
import org.geobon.pipeline.ConstantPipe

class DelayPipe(private val delay: Long, value: String, private val finishLine: MutableList<String>? = null) :
    ConstantPipe("text/plain", value) {

    override suspend fun pull(): Any {
        delay(delay)

        return super.pull()
            .also { finishLine?.add(it.toString()) }
    }
}