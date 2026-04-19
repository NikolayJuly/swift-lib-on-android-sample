# Android side

Gradle project that consumes the Swift codebase as `.so` libraries. For
project-wide setup and quick start, see the [root README](../README.md).
This document covers the Android-specific gradual-loading model.

## Module layout

```
Android/
├── swift-runtime/        # Stage 1: core Swift runtime libs (no business code)
├── pokemon-swift/        # Stage 2: PokemonKit .so + Kotlin JNI wrapper
└── app/                  # Sample Compose app
```

## Gradual loading model

Native loading is staged so the runtime is reusable across business modules
and each stage is explicit:

1. **`swift-runtime`** loads the core Swift libraries listed in
   `swift-runtime/src/main/assets/swift-libs-manifest.json` —
   `BlocksRuntime`, `c++_shared`, `dispatch`, `swiftCore`, `swiftAndroid`,
   `swiftDispatch`, `swiftSynchronization`, `swift_Concurrency`,
   `swift_RegexParser`, `swift_StringProcessing`, `FoundationEssentials`,
   `FoundationInternationalization`, `Foundation`, `SwiftJava`. It binds
   libdispatch's main queue to the JVM main thread and runs a
   high-frequency drain loop while the app is active.
2. **`pokemon-swift`** depends on `:swift-runtime`. On its `configure()` it
   asserts `SwiftRuntime.isConfigured`, then loads its own `.so`
   (`libPokemonKitAndroid.so`) and calls `nativeCreate` on the JNI bridge.

The split keeps `swift-runtime` product-agnostic: any future Swift module
(e.g. another business domain) can plug in by adding its own `:foo-swift`
gradle module + manifest, depending on `:swift-runtime`.

## Local setup

Set `local.properties` with your Android SDK location:

```
sdk.dir=/Users/<you>/Library/Android/sdk
```

Build and test from the command line:

```
./gradlew :swift-runtime:assembleDebug
./gradlew :swift-runtime:testDebugUnitTest
./gradlew :app:installDebug
```

The Swift `.so` files are produced automatically as part of the build —
the `buildSwiftLibs` Gradle task invokes `Scripts/build-android-so.sh`,
which runs `swift-android-bundler` against the Swift package. The bundler
itself is bootstrapped on first build into `.tools/` (gitignored). See the
[root README](../README.md) for prerequisites.
