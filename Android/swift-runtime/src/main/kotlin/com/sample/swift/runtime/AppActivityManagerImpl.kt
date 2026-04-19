package com.sample.swift.runtime

import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicLong
import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds

/**
 * Production implementation of [AppActivityManager].
 *
 * Uses [ProcessLifecycleOwner] to detect foreground/background transitions.
 * When app enters background, keeps [isActive] = true for [defaultGracePeriod].
 * [requestBackgroundTime] extends grace period up to [hardCapDuration] from
 * the moment app entered background (hard cap job always wins).
 */
class AppActivityManagerImpl(
    private val logger: SwiftRuntimeLogger,
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob()),
    private val delayFunction: suspend (Duration) -> Unit = { delay(it) },
    private val defaultGracePeriod: Duration = 5.seconds,
    private val hardCapDuration: Duration = 30.seconds
) : AppActivityManager {

    private val _isInForeground = MutableStateFlow(true)
    override val isInForeground: StateFlow<Boolean> = _isInForeground.asStateFlow()

    private val _isActive = MutableStateFlow(true)
    override val isActive: StateFlow<Boolean> = _isActive.asStateFlow()

    private val tokenCounter = AtomicLong(0)
    private val activeTokens = mutableSetOf<BackgroundTaskToken>()
    private val lock = Any()

    private var inForeground = true
    private var defaultGraceExpired = false
    private var gracePeriodJob: Job? = null
    private var hardCapJob: Job? = null

    private val lifecycleObserver = object : DefaultLifecycleObserver {
        override fun onStart(owner: LifecycleOwner) = onEnteredForeground()
        override fun onStop(owner: LifecycleOwner) = onEnteredBackground()
    }

    fun attachToLifecycle() {
        ProcessLifecycleOwner.get().lifecycle.addObserver(lifecycleObserver)
    }

    override fun requestBackgroundTime(): BackgroundTaskToken {
        val token = BackgroundTaskToken(tokenCounter.incrementAndGet())
        synchronized(lock) {
            activeTokens.add(token)
        }
        return token
    }

    override fun endBackgroundTask(token: BackgroundTaskToken) {
        synchronized(lock) {
            activeTokens.remove(token)
            if (!inForeground && activeTokens.isEmpty()) {
                checkShouldDeactivate()
            }
        }
    }

    // MARK: - Internal (visible for testing)

    internal fun onEnteredForeground() {
        logger.d(TAG, "App entered foreground")
        synchronized(lock) {
            inForeground = true
            defaultGraceExpired = false
            gracePeriodJob?.cancel()
            gracePeriodJob = null
            hardCapJob?.cancel()
            hardCapJob = null
            _isInForeground.value = true
            _isActive.value = true
        }
    }

    internal fun onEnteredBackground() {
        logger.d(TAG, "App entered background")
        synchronized(lock) {
            inForeground = false
            defaultGraceExpired = false
            _isInForeground.value = false
            startDefaultGracePeriod()
            startHardCap()
        }
    }

    // MARK: - Private

    private fun startDefaultGracePeriod() {
        gracePeriodJob?.cancel()
        gracePeriodJob = scope.launch {
            delayFunction(defaultGracePeriod)
            synchronized(lock) {
                defaultGraceExpired = true
                if (!inForeground && activeTokens.isEmpty()) {
                    deactivate()
                }
            }
        }
    }

    private fun startHardCap() {
        hardCapJob?.cancel()
        hardCapJob = scope.launch {
            delayFunction(hardCapDuration)
            synchronized(lock) {
                if (!inForeground) {
                    logger.w(TAG, "Hard cap reached ($hardCapDuration), forcing deactivation")
                    deactivate()
                }
            }
        }
    }

    private fun checkShouldDeactivate() {
        // All tokens released. If default grace period already passed, deactivate now.
        // Otherwise, the default grace period job will handle it when it expires.
        if (defaultGraceExpired) {
            deactivate()
        }
    }

    private fun deactivate() {
        gracePeriodJob?.cancel()
        gracePeriodJob = null
        hardCapJob?.cancel()
        hardCapJob = null
        _isActive.value = false
        logger.d(TAG, "App deactivated")
    }

    companion object {
        private const val TAG = "AppActivityManager"
    }
}
