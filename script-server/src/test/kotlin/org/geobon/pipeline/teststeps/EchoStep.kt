package org.geobon.pipeline.teststeps

import org.geobon.pipeline.ConstantPipe
import org.geobon.pipeline.Output
import org.geobon.pipeline.Step

/**
 * Dummy test step:
 * - Transfers param sound to output KEY.
 * - Output BAD_KEY will stay null.
 */
class EchoStep(sound: String) :
    Step(
        mutableMapOf(SOUND to ConstantPipe("text/plain", sound)),
        mapOf(
            KEY to Output("text/plain"),
            BAD_KEY to Output("text/plain")
        )
    ) {

    companion object {
        const val KEY = "echo"
        const val BAD_KEY = "no-echo"

        private const val SOUND = "sound"
    }

    override suspend fun execute(resolvedInputs: Map<String, Any>): Map<String, Any> {
        return mapOf(KEY to resolvedInputs[SOUND]!!)
    }
}