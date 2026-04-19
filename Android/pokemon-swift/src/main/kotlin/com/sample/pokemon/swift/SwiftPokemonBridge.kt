package com.sample.pokemon.swift

import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import com.sample.pokemon.proto.PokemonListState

/**
 * Kotlin-side counterpart of the Swift `@JavaClass("com.sample.pokemon.swift.SwiftPokemonBridge")`.
 *
 * - Kotlin → Swift: `external fun nativeXxx()` — JNI-mangled to `Java_com_sample_pokemon_swift_SwiftPokemonBridge_nativeXxx`,
 *   resolved against `libPokemonKitAndroid.so` once it's loaded.
 * - Swift → Kotlin: Swift calls `bridgeRef.onStateUpdate(bytes)` / `logMessage` / `logError`
 *   on this object via JNI. Methods are intentionally `public` and not stripped (no
 *   ProGuard rules needed in this sample; debug build only).
 */
class SwiftPokemonBridge {

    private val _states = MutableStateFlow(PokemonListState.getDefaultInstance())
    val states: StateFlow<PokemonListState> = _states.asStateFlow()

    external fun nativeConfigure(dataDir: String, filesDir: String, noBackupDir: String, cacheDir: String)
    external fun nativeCreate(filesDir: String, deviceInfoJson: String)
    external fun nativeRefresh()
    external fun nativeOnBecameActive()
    external fun nativeOnEnteredBackground()

    @Suppress("unused")
    fun onStateUpdate(bytes: ByteArray) {
        try {
            _states.value = PokemonListState.parseFrom(bytes)
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to decode PokemonListState bytes (${bytes.size}B): $e")
        }
    }

    @Suppress("unused")
    fun logMessage(message: String) {
        Log.i(TAG, message)
    }

    @Suppress("unused")
    fun logError(source: String, message: String) {
        Log.e(TAG, "[$source] $message")
    }

    companion object {
        private const val TAG = "SwiftPokemonBridge"
    }
}
