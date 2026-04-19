package com.sample.swift.runtime

interface SwiftRuntimeLogger {
    fun d(subtag: String, message: String)
    fun i(subtag: String, message: String)
    fun w(subtag: String, message: String)
    fun e(subtag: String, message: String)

    /**
     * Info-level log used for key lifecycle events (init started/finished, etc.).
     * In production builds this would also be forwarded to a crash-report service
     * (e.g. Crashlytics breadcrumbs); in this sample it's a plain info log.
     */
    fun external(subtag: String, message: String)

    /**
     * Report a recoverable error or failed-init event. In production apps this is
     * where crash-reporting backends (Crashlytics, Sentry, etc.) get a hook —
     * see TODO.md for the integration pattern.
     */
    fun report(subtag: String, message: String, throwable: Throwable)
}
