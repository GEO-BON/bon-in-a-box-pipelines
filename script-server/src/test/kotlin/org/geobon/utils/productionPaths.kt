package org.geobon.utils

import io.kotest.extensions.system.OverrideMode
import io.kotest.extensions.system.withEnvironment
import java.io.File

val productionPipelinesRoot: File = File(File("").absoluteFile.parent, "pipelines")
val productionScriptsRoot: File = File(File("").absoluteFile.parent, "scripts")

/**
 * Use script and pipeline production paths.
 * This does NOT include output path on purpose, not to mix test outputs with production outputs.
 */
inline fun <T> withProductionPaths(block: () -> T): T {
    println("""
            |Using production paths:
            |   pipelines=${File(System.getenv("PIPELINES_LOCATION"))}
            |   scripts=${File(System.getenv("SCRIPT_LOCATION"))}
        """.trimMargin())

    return withEnvironment("PIPELINES_LOCATION", productionPipelinesRoot.absolutePath, OverrideMode.SetOrOverride) {
        withEnvironment("SCRIPT_LOCATION", productionScriptsRoot.absolutePath, OverrideMode.SetOrOverride) {
            block()
        }
    }
}

/**
 * Use script production paths.
 * This does NOT include pipeline and output path on purpose
 */
inline fun <T> withProductionScripts(block: () -> T): T {
    return withEnvironment("SCRIPT_LOCATION", productionScriptsRoot.absolutePath, OverrideMode.SetOrOverride) {
        block()
    }
}
