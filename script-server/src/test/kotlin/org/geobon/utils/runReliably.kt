package org.geobon.utils

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import java.util.*
import kotlin.coroutines.CoroutineContext
import kotlin.coroutines.EmptyCoroutineContext

/**
 * From https://github.com/Kotlin/kotlinx.coroutines/issues/1205#issuecomment-1203174032
 * and https://github.com/Kotlin/kotlinx.coroutines/issues/1205#issuecomment-1238261240
 */

/**
 * Runs a function, making sure that the exceptions that happen throughout its execution get reported.
 */
fun<T> runReliably(
    testBody: () -> T,
): T {
    val oldHandler = Thread.getDefaultUncaughtExceptionHandler()
    val errors = Vector<Throwable>()
    try {
        Thread.setDefaultUncaughtExceptionHandler { _, throwable -> errors.add(throwable) }
        val result = try {
            testBody()
        } catch (testError: Throwable) {
            for (e in errors) {
                testError.addSuppressed(e)
            }
            throw testError
        }
        errors.firstOrNull()?.apply {
            errors.drop(1).forEach { addSuppressed(it) }
            println("Caught: ${message}")
            throw this
        }
        return result
    } finally {
        Thread.setDefaultUncaughtExceptionHandler(oldHandler)
    }
}

/**
 * Run a coroutine test, making sure the uncaught exceptions that happen during the execution of the test do get reported.
 */
@OptIn(ExperimentalCoroutinesApi::class)
fun runReliableTest(
    context: CoroutineContext = EmptyCoroutineContext,
    dispatchTimeoutMs: Long = 30_000L,
    testBody: suspend TestScope.() -> Unit
) = runReliably {
    runTest(context, dispatchTimeoutMs, testBody)
}