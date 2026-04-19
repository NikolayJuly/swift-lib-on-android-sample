package com.sample.pokemon

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.lifecycle.lifecycleScope
import com.sample.pokemon.swift.PokemonSwiftRuntime
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        val splash = installSplashScreen()
        super.onCreate(savedInstanceState)

        val app = application as PokemonApp
        // Hold the splash until SwiftRuntime + PokemonSwiftRuntime have finished.
        splash.setKeepOnScreenCondition { app.swiftReady.value.not() }

        // Once Swift is up, render the list backed by the bridge's StateFlow.
        lifecycleScope.launch {
            app.swiftReady.first { it }
            setContent {
                val state by PokemonSwiftRuntime.bridge.states.collectAsState()
                PokemonScreen(
                    state = state,
                    onRefresh = { PokemonSwiftRuntime.bridge.nativeRefresh() },
                )
            }
        }
    }
}
