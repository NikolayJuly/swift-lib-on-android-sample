package com.sample.swift.runtime

/**
 * Drains Swift's main dispatch queue.
 * Called from a high-frequency loop while the app is active so that Swift's
 * libdispatch main queue tasks (MainActor work, Task { @MainActor in ... },
 * timers, asyncAfter) actually execute on the JVM main thread.
 *
 * Wrapped in try/catch so that early calls (before the dispatch .so is loaded)
 * don't crash with UnsatisfiedLinkError.
 */
object MainQueueDrainer {

    fun drain() {
        try {
            nativeDrainMainQueue()
        } catch (_: UnsatisfiedLinkError) { }
    }

    private external fun nativeDrainMainQueue()
}
