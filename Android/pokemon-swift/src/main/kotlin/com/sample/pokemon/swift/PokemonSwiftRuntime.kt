package com.sample.pokemon.swift

import android.content.Context
import android.os.Build
import com.sample.swift.runtime.SwiftRuntime
import com.sample.swift.runtime.SwiftRuntimeLogger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Stage 2 loader: assumes [SwiftRuntime] core libs are already loaded, then loads
 * `libPokemonKitAndroid.so` (declared in `pokemon-libs-manifest.json`) and calls
 * the Swift bridge's `nativeCreate`. Safe to call multiple times — only the first
 * does work.
 */
object PokemonSwiftRuntime {

    private const val TAG = "PokemonSwiftRuntime"
    private const val MANIFEST_FILE = "pokemon-libs-manifest.json"

    private val didConfigure = AtomicBoolean(false)

    /** Singleton bridge — Swift pushes state updates onto its `StateFlow`. */
    val bridge = SwiftPokemonBridge()

    suspend fun configure(context: Context, logger: SwiftRuntimeLogger): Boolean {
        check(SwiftRuntime.isConfigured) {
            "SwiftRuntime.configure() must complete before PokemonSwiftRuntime.configure()"
        }
        if (!didConfigure.compareAndSet(false, true)) {
            logger.w(TAG, "PokemonSwiftRuntime.configure() already called, ignoring")
            return false
        }

        val libs = readManifest(context)
        if (libs.isEmpty()) {
            logger.w(TAG, "Manifest is empty — no .so files yet. Run Scripts/build-android-so.sh.")
            return true
        }
        for (lib in libs) {
            logger.d(TAG, "Loading $lib")
            System.loadLibrary(lib)
        }

        // Stash Context-derived directory paths into Swift's `AndroidAppDirectories`
        // singleton — see Toolkit/FoundationExtension/.../AndroidAppDirectories.swift.
        // Safe from any thread; must happen after the product .so is loaded.
        bridge.nativeConfigure(
            dataDir = context.dataDir.absolutePath,
            filesDir = context.filesDir.absolutePath,
            noBackupDir = context.noBackupFilesDir.absolutePath,
            cacheDir = context.cacheDir.absolutePath,
        )

        val deviceInfoJson = json.encodeToString(buildDeviceInfo(context))
        withContext(Dispatchers.Main) {
            bridge.nativeCreate(context.filesDir.absolutePath, deviceInfoJson)
        }
        logger.i(TAG, "PokemonSwiftRuntime configured")
        return true
    }

    // MARK: - Private

    private val json = Json { ignoreUnknownKeys = true }

    private fun readManifest(context: Context): List<String> {
        val text = context.assets.open(MANIFEST_FILE).bufferedReader().use { it.readText() }
        return json.decodeFromString<PokemonLibsManifest>(text).libraries
    }

    private fun buildDeviceInfo(context: Context): DeviceInfoJson {
        val pkg = context.packageName
        val versionName = runCatching {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(pkg, 0).versionName
        }.getOrNull() ?: "0.0"
        return DeviceInfoJson(
            modelRawName = "${Build.MANUFACTURER} ${Build.MODEL}",
            appVersion = versionName,
            appIdentifier = pkg,
        )
    }

    @Serializable
    private data class PokemonLibsManifest(val libraries: List<String>)

    @Serializable
    private data class DeviceInfoJson(
        val modelRawName: String,
        val appVersion: String,
        val appIdentifier: String,
    )
}
