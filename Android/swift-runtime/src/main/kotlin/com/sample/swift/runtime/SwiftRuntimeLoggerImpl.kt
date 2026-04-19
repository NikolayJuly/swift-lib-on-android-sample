package com.sample.swift.runtime

import android.util.Log

/**
 * Plain Logcat-only implementation suitable for the open-source sample.
 * Production apps would forward errors to their crash-reporting backend.
 */
class SwiftRuntimeLoggerImpl : SwiftRuntimeLogger {

    override fun d(subtag: String, message: String) {
        Log.d(LOGCAT_TAG, format(subtag, message))
    }

    override fun i(subtag: String, message: String) {
        Log.i(LOGCAT_TAG, format(subtag, message))
    }

    override fun w(subtag: String, message: String) {
        Log.w(LOGCAT_TAG, format(subtag, message))
    }

    override fun e(subtag: String, message: String) {
        Log.e(LOGCAT_TAG, format(subtag, message))
    }

    override fun external(subtag: String, message: String) {
        Log.i(LOGCAT_TAG, format(subtag, message))
    }

    override fun report(subtag: String, message: String, throwable: Throwable) {
        // Production fork: forward to Crashlytics/Sentry here.
        Log.e(LOGCAT_TAG, format(subtag, message), throwable)
    }

    private fun format(subtag: String, message: String): String =
        "[$subtag] $message"

    companion object {
        private const val LOGCAT_TAG = "SwiftRuntime"
    }
}
