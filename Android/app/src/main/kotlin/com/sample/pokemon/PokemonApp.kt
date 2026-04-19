package com.sample.pokemon

import android.app.Application
import com.sample.pokemon.swift.PokemonSwiftRuntime
import com.sample.pokemon.swift.SwiftPokemonBridge
import com.sample.swift.runtime.AppActivityManagerImpl
import com.sample.swift.runtime.SwiftRuntime
import com.sample.swift.runtime.SwiftRuntimeLoggerImpl
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * Process-global singletons for the sample. On `onCreate`:
 *  1. Wires AppActivityManager into ProcessLifecycleOwner.
 *  2. Configures SwiftRuntime — loads core .so libs, binds dispatch main queue,
 *     starts drain loop.
 *  3. Configures PokemonSwiftRuntime — loads `libPokemonKitAndroid.so` and
 *     calls `nativeCreate`. Swift starts pushing state updates immediately.
 *  4. Sets [swiftReady] = true → MainActivity's splash dismisses.
 *
 * Failures are swallowed (logged) for the sample — production apps would surface
 * them to the user.
 */
class PokemonApp : Application() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val _swiftReady = MutableStateFlow(false)
    val swiftReady: StateFlow<Boolean> = _swiftReady.asStateFlow()

    val bridge: SwiftPokemonBridge get() = PokemonSwiftRuntime.bridge

    override fun onCreate() {
        super.onCreate()
        val logger = SwiftRuntimeLoggerImpl()
        val activityManager = AppActivityManagerImpl(logger).also { it.attachToLifecycle() }

        scope.launch {
            val ok = SwiftRuntime.configure(this@PokemonApp, activityManager, logger)
            if (!ok) {
                logger.e("PokemonApp", "SwiftRuntime.configure failed")
                return@launch
            }
            PokemonSwiftRuntime.configure(this@PokemonApp, logger)
            _swiftReady.value = true
            logger.i("PokemonApp", "Swift stack ready")
        }
    }
}
