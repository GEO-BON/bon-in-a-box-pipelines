package org.geobon.utils

import java.io.File
import java.util.concurrent.TimeUnit


fun String.runCommand(
    workingDir: File = File("."),
    timeoutAmount: Long = 1,
    timeoutUnit: TimeUnit = TimeUnit.SECONDS
): String? = runCatching {
    println("bash -c $this")
    ProcessBuilder("bash", "-c", this)
        .directory(workingDir)
        .redirectOutput(ProcessBuilder.Redirect.PIPE)
        .redirectErrorStream(true) // Merges stderr into stdout
        .start().also { it.waitFor(timeoutAmount, timeoutUnit) }
        .inputStream.bufferedReader().readText()
}.onFailure { it.printStackTrace() }.getOrNull()