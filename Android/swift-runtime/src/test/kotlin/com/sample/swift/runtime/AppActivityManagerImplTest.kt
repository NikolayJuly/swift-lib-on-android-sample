package com.sample.swift.runtime

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds

@OptIn(ExperimentalCoroutinesApi::class)
class AppActivityManagerImplTest {

    private val noOpLogger = object : SwiftRuntimeLogger {
        override fun d(subtag: String, message: String) = Unit
        override fun i(subtag: String, message: String) = Unit
        override fun w(subtag: String, message: String) = Unit
        override fun e(subtag: String, message: String) = Unit
        override fun external(subtag: String, message: String) = Unit
        override fun report(subtag: String, message: String, throwable: Throwable) = Unit
    }

    private fun createManager(
        testScope: TestScope,
        defaultGracePeriod: Duration = 5.seconds,
        hardCapDuration: Duration = 30.seconds
    ): AppActivityManagerImpl {
        return AppActivityManagerImpl(
            logger = noOpLogger,
            scope = testScope,
            delayFunction = { duration -> delay(duration) },
            defaultGracePeriod = defaultGracePeriod,
            hardCapDuration = hardCapDuration
        )
    }

    @Test
    fun `initially isActive is true`() = runTest {
        val manager = createManager(this)
        assertTrue(manager.isActive.value)
    }

    @Test
    fun `after entering background, isActive stays true during grace period`() = runTest {
        val manager = createManager(this)
        manager.onEnteredBackground()

        advanceTimeBy(3.seconds)
        assertTrue("Should still be active within 5s grace period", manager.isActive.value)
    }

    @Test
    fun `after entering background, isActive becomes false after grace period`() = runTest {
        val manager = createManager(this)
        manager.onEnteredBackground()

        advanceTimeBy(5.seconds + Duration.parse("1ms"))
        assertFalse("Should be inactive after 5s grace period", manager.isActive.value)
    }

    @Test
    fun `returning to foreground before grace period cancels deactivation`() = runTest {
        val manager = createManager(this)
        manager.onEnteredBackground()

        advanceTimeBy(3.seconds)
        assertTrue(manager.isActive.value)

        manager.onEnteredForeground()
        advanceTimeBy(10.seconds)
        assertTrue("Should remain active after returning to foreground", manager.isActive.value)
    }

    @Test
    fun `requestBackgroundTime extends grace period`() = runTest {
        val manager = createManager(this)
        manager.onEnteredBackground()

        // Request extra time before default 5s expires
        advanceTimeBy(3.seconds)
        val token = manager.requestBackgroundTime()

        // Default 5s would have expired, but token keeps it alive
        advanceTimeBy(4.seconds)
        assertTrue("Should still be active with outstanding token", manager.isActive.value)

        // Release token
        manager.endBackgroundTask(token)
        // Grace period job already expired, so should deactivate immediately
        assertFalse("Should deactivate after token released and grace expired", manager.isActive.value)
    }

    @Test
    fun `hard cap forces deactivation even with active tokens`() = runTest {
        val manager = createManager(this, hardCapDuration = 30.seconds)
        manager.onEnteredBackground()

        val token = manager.requestBackgroundTime()

        advanceTimeBy(30.seconds + Duration.parse("1ms"))
        assertFalse("Hard cap should force deactivation", manager.isActive.value)

        // Cleanup
        manager.endBackgroundTask(token)
    }

    @Test
    fun `multiple tokens - deactivation waits for all to be released`() = runTest {
        val manager = createManager(this)
        manager.onEnteredBackground()

        val token1 = manager.requestBackgroundTime()
        val token2 = manager.requestBackgroundTime()

        advanceTimeBy(6.seconds)
        assertTrue("Should still be active with outstanding tokens", manager.isActive.value)

        manager.endBackgroundTask(token1)
        assertTrue("Should still be active with one token remaining", manager.isActive.value)

        manager.endBackgroundTask(token2)
        assertFalse("Should deactivate after all tokens released", manager.isActive.value)
    }

    @Test
    fun `requestBackgroundTime in foreground is no-op`() = runTest {
        val manager = createManager(this)

        val token = manager.requestBackgroundTime()
        assertTrue("Should remain active in foreground", manager.isActive.value)

        manager.endBackgroundTask(token)
        assertTrue("Should remain active in foreground after token release", manager.isActive.value)
    }

    @Test
    fun `re-entering foreground resets state for next background cycle`() = runTest {
        val manager = createManager(this)

        manager.onEnteredBackground()
        advanceTimeBy(3.seconds)
        manager.onEnteredForeground()

        manager.onEnteredBackground()
        advanceTimeBy(5.seconds + Duration.parse("1ms"))
        assertFalse("Second background cycle should deactivate after grace period", manager.isActive.value)
    }

    @Test
    fun `returning to foreground after deactivation reactivates`() = runTest {
        val manager = createManager(this)

        manager.onEnteredBackground()
        advanceTimeBy(6.seconds)
        assertFalse(manager.isActive.value)

        manager.onEnteredForeground()
        assertTrue("Should reactivate on foreground", manager.isActive.value)
    }
}
