package org.geobon.utils

import io.kotest.extensions.system.OverrideMode
import io.kotest.extensions.system.withEnvironment
import java.io.File

val productionPipelinesRoot: File = File("/pipelines").let {
        // in the docker
        if(it.exists()) it 
        // intelliJ on local computer
        else File(File("").absoluteFile.parent, "pipelines")
    }
    

val productionScriptsRoot: File = File("/scripts").let {
        // in the docker
        if(it.exists()) it 
        // intelliJ on local computer
        else File(File("").absoluteFile.parent, "scripts")
    }

/**
 * Use script and pipeline production paths.
 * This does NOT include output path on purpose, not to mix test outputs with production outputs.
 */
inline fun <T> withProductionPaths(block: () -> T): T {
    

    return withEnvironment("PIPELINES_LOCATION", productionPipelinesRoot.absolutePath, OverrideMode.SetOrOverride) {
        withEnvironment("SCRIPT_LOCATION", productionScriptsRoot.absolutePath, OverrideMode.SetOrOverride) {
            println("""
                    |Using production paths:
                    |   pipelines=${System.getenv("PIPELINES_LOCATION")}
                    |   scripts=${System.getenv("SCRIPT_LOCATION")}
                """.trimMargin())

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
