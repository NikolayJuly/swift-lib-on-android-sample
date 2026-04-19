package com.sample.swift.runtime

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Configures Swift runtime for Android.
 *
 * Loads core Swift libs (Concurrency, Dispatch, Foundation, swift-java) listed in
 * `assets/swift-libs-manifest.json`, binds libdispatch's main queue to the JVM main
 * thread, and starts a high-frequency main-queue drain loop (~1ms) gated by
 * [AppActivityManager.isActive] so Swift's MainActor work actually runs.
 *
 * Business product libraries (e.g. PokemonKit) are NOT loaded here — they live in
 * their own Gradle module (e.g. `:pokemon-swift`) which depends on `:swift-runtime`,
 * checks [isConfigured], and loads its own `.so` files. This keeps the runtime
 * product-agnostic and lets app-level code stage native loading explicitly.
 */
object SwiftRuntime {

    private const val TAG = "SwiftRuntime"
    private const val MANIFEST_FILE = "swift-libs-manifest.json"
    private const val DISPATCH_LIB = "dispatch"
    private const val FOUNDATION_ESSENTIALS_LIB = "FoundationEssentials"
    private const val FOUNDATION_LIB = "Foundation"

    /**
     * Libraries that must be loaded on the Main thread because their global
     * constructors bind libdispatch's main queue to the loading thread.
     *
     * - `libdispatch.so` — binds the main queue directly from its own
     *   constructors at dlopen time.
     * - `libFoundationEssentials.so` — its constructors touch main-queue-aware
     *   APIs (most likely `RunLoop.main` and surroundings), which re-binds the
     *   main queue to the loader.
     * - `libFoundation.so` — same root cause as FoundationEssentials. Only ships
     *   in builds that did not exclude Foundation (debug, or `--exclude none`);
     *   when it is absent from the manifest, the entry is a no-op.
     *
     * If the main queue ends up bound to a non-Main thread, the first drain on
     * Main crashes with `brk #0x1` inside `_dispatch_main_queue_callback_4CF`.
     */
    private val MAIN_THREAD_LIBS = setOf(
        DISPATCH_LIB,
        FOUNDATION_ESSENTIALS_LIB,
        FOUNDATION_LIB,
    )

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val didTriggerConfigure = AtomicBoolean(false)
    private val didFinishConfigure = AtomicBoolean(false)
    private val drainScheduled = AtomicBoolean(false)

    private lateinit var logger: SwiftRuntimeLogger
    @Volatile
    private var drainJob: Job? = null
    private var observeJob: Job? = null

    val isSupported: Boolean = Build.VERSION.SDK_INT >= 28 &&
        (System.getProperty("os.arch")
            ?.let { it == "aarch64" || it.startsWith("arm64") ||
                    it == "x86_64" || it == "amd64" }
            ?: false)

    /**
     * `true` once [configure] has finished successfully. Downstream loaders
     * (e.g. `:pokemon-swift`) must check this before loading their own `.so`s,
     * since those depend on symbols from the core libs loaded here.
     */
    val isConfigured: Boolean get() = didFinishConfigure.get()

    /**
     * Configure the Swift runtime. Can be called from any thread.
     * Safe to call multiple times — second call is a no-op.
     *
     * Libraries listed in [MAIN_THREAD_LIBS] are loaded on the Main thread —
     * see the doc on [MAIN_THREAD_LIBS] for the reasoning. All other .so files
     * are loaded on the calling thread.
     *
     * After loading, performs an initial drain on Main to bind the main queue,
     * then starts observing [appActivityManager] to control the drain loop.
     *
     * If the manifest is empty (e.g. the `.so` files haven't been generated yet
     * via the Swift→Android build script), this short-circuits with a warning
     * and returns `true` so app code can keep moving in dev environments.
     */
    suspend fun configure(context: Context,
                          appActivityManager: AppActivityManager,
                          logger: SwiftRuntimeLogger): Boolean {
        this.logger = logger
        val isFirstCall = didTriggerConfigure.compareAndSet(false, true)
        if (!isFirstCall) {
            logger.w(TAG, "SwiftRuntime.configure() already called, ignoring")
            return false
        }

        logger.external(TAG, "Runtime init started")

        val libs = readManifest(context)
        if (libs.isEmpty()) {
            logger.w(TAG, "Manifest is empty — no .so files yet. Run the Swift→Android build script.")
            didFinishConfigure.set(true)
            return true
        }

        val loaded = loadNativeLibraries(context, libs, logger)
        if (!loaded) {
            val reason = "Native libraries not available, Swift runtime will not be configured"
            logger.report(TAG, reason, Throwable(reason))
            return false
        }

        // Immediately bind libdispatch main queue to Main thread by performing
        // the first drain. Must happen before any nativeCreate or
        // Task { @MainActor in } in downstream modules.
        withContext(Dispatchers.Main) {
            MainQueueDrainer.drain()
        }
        observeActivityState(appActivityManager)
        logger.i(TAG, "Main queue bound to Main thread, drain loop started")
        logger.external(TAG, "Runtime init finished")
        didFinishConfigure.set(true)
        return true
    }

    // MARK: - Private

    private suspend fun loadNativeLibraries(context: Context,
                                            libs: List<String>,
                                            logger: SwiftRuntimeLogger): Boolean {
        logger.i(TAG, "Manifest: ${libs.size} libraries: ${libs.joinToString()}")

        val libDir = File(context.applicationInfo.nativeLibraryDir)
        val firstLib = libs.first()
        val firstFile = File(libDir, "lib${firstLib}.so")
        if (!firstFile.exists()) {
            val reason = "lib${firstLib}.so not found in $libDir " +
                "(process 64-bit: ${android.os.Process.is64Bit()}, " +
                "ABIs: ${Build.SUPPORTED_ABIS.joinToString()})"
            logger.report(TAG, reason, Throwable(reason))
            return false
        }

        for (lib in libs) {
            if (lib in MAIN_THREAD_LIBS) {
                logger.d(TAG, "Loading $lib (on Main thread)")
                withContext(Dispatchers.Main) {
                    System.loadLibrary(lib)
                }
            } else {
                logger.d(TAG, "Loading $lib")
                System.loadLibrary(lib)
            }
        }
        logger.i(TAG, "Loaded all ${libs.size} libraries")
        return true
    }

    private val manifestJson = Json { ignoreUnknownKeys = true }

    private fun readManifest(context: Context): List<String> {
        val json = context.assets.open(MANIFEST_FILE).bufferedReader().use { it.readText() }
        return manifestJson.decodeFromString<SwiftLibsManifest>(json).libraries
    }

    private fun observeActivityState(appActivityManager: AppActivityManager) {
        observeJob = scope.launch {
            appActivityManager.isActive.collect { active ->
                if (active) {
                    startDraining()
                } else {
                    stopDraining()
                }
            }
        }
    }

    private fun startDraining() {
        if (drainJob?.isActive == true) return
        logger.d(TAG, "Starting drain loop")
        drainJob = scope.launch {
            while (isActive) {
                if (drainScheduled.compareAndSet(false, true)) {
                    mainHandler.post {
                        MainQueueDrainer.drain()
                        drainScheduled.set(false)
                    }
                }
                delay(1)
            }
        }
    }

    private fun stopDraining() {
        logger.d(TAG, "Stopping drain loop")
        drainJob?.cancel()
        drainJob = null
        // Final drain to flush any remaining Swift main queue tasks
        mainHandler.post { MainQueueDrainer.drain() }
    }
}

@Serializable
private data class SwiftLibsManifest(val libraries: List<String>)
