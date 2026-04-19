package com.sample.swift.runtime

import kotlinx.coroutines.flow.StateFlow

/**
 * Tracks app foreground/background state with grace period support.
 *
 * When app goes to background, [isActive] stays `true` for a default grace period (5s).
 * Consumers can request extra background time via [requestBackgroundTime],
 * extending the grace period up to a hard cap (30s from the moment app entered background).
 *
 * When app returns to foreground, any pending expiration is cancelled and [isActive] stays `true`.
 */
interface AppActivityManager {

    /** `true` while app is in foreground. Changes immediately on lifecycle transitions. */
    val isInForeground: StateFlow<Boolean>

    /** `true` while app is in foreground or within background grace period. */
    val isActive: StateFlow<Boolean>

    /**
     * Request extra background time. Returns a token that must be released
     * via [endBackgroundTask] when done.
     *
     * In foreground — no-op, returns a token immediately.
     * In background — extends grace period up to the hard cap.
     */
    fun requestBackgroundTime(): BackgroundTaskToken

    /** Release a previously acquired background task token. */
    fun endBackgroundTask(token: BackgroundTaskToken)
}

@JvmInline
value class BackgroundTaskToken(val id: Long)
