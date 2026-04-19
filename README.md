# swift-lib-on-android-sample

Sample project showing how to share a Swift module between iOS and Android,
using [PokéAPI](https://pokeapi.co) as a toy domain. Shared business logic
lives in Swift; UI is native on each platform.

## What this demonstrates

- A single Swift module (`PokemonKit`) consumed by both an iOS and an Android
  app — view model, networking, caching, all in Swift.
- Native UI per platform: SwiftUI on iOS, Jetpack Compose on Android.
- **Protobuf as the JNI-friendly contract** between Swift and Kotlin — only
  byte arrays cross the JNI boundary.
- Three flavors of persistence in one sample: JSON-on-disk cache, network →
  cache pipeline, and a key/value store for small metadata.

## Prerequisites

- **macOS** with **Xcode** (for iOS) and **Android Studio** (for Android),
  including the Android SDK and NDK (default location:
  `~/Library/Android/sdk`).
- [**swiftly**](https://www.swift.org/install/) — Swift toolchain manager.
- **Swift 6.3.0** toolchain installed via swiftly:
  ```
  swiftly install 6.3.0
  ```
- **Swift for Android SDK** (matches the toolchain version):
  ```
  swift sdk install https://download.swift.org/swift-6.3.2-release/android-sdk/swift-6.3.2-RELEASE/swift-6.3.2-RELEASE_android.artifactbundle.tar.gz --checksum 939e933549d12d28f2e0bf71019d734d309859e9773c572657ce565a81f85d68
  ```
  See the [Swift for Android](https://www.swift.org/install/) docs for the
  exact URL of the latest 6.3 SDK release.
- **patchelf** and **jq** for the `.so` build pipeline:
  ```
  brew install patchelf jq
  ```

That is everything the user has to install. Everything else — including the
`swift-android-bundler` CLI used to build the Swift code into Android `.so`
libraries — is bootstrapped automatically on the first Android build.

## Repo layout

```
Toolkit/
├── CacheKit/                # Tiny JSON-cache service (`JsonCacheKit` target)
├── FoundationExtension/     # Foundation extras shared across modules
└── NetworkKit/              # NetworkKitAPI + NetworkKitFoundation + NetworkKitAndroid
Modules/
└── PokemonKit/              # Shared Swift: API, cache, view model, JNI bridge, .proto
iOS/
└── PokemonSample/           # SwiftUI app
Android/
├── app/                     # Compose UI + splash screen
├── swift-runtime/           # .so loader, libdispatch main-queue drain (product-agnostic)
└── pokemon-swift/           # PokemonKit .so + Kotlin JNI wrapper (decodes protobuf)
Scripts/
├── bootstrap-tools.sh       # Clones + builds swift-android-bundler into .tools/
└── build-android-so.sh      # Builds .so files via the bundler
.tools/                      # gitignored — bootstrap output lives here
```

## iOS — quick start

1. Open `iOS/PokemonSample/PokemonSample.xcodeproj` in Xcode.
2. Select an iOS Simulator and Run.

Swift dependencies resolve through SwiftPM; nothing else is required.

## Android — quick start

1. Open the `Android/` folder in Android Studio.
2. Pick (or start) an emulator / connected device and Run the `app`
   configuration.

The first build clones `swift-android-bundler` v0.3.1 into `.tools/` and
compiles it (~20 seconds), then builds the Swift code into `.so` libraries
for `arm64-v8a`, `x86_64`, and `armeabi-v7a`. Subsequent builds are
incremental — both the bundler and the Swift package are cached.

If you want to rebuild the `.so`s manually:

```
./Scripts/build-android-so.sh
```

## How it works

- The Swift package (`Modules/PokemonKit`) holds the view model and exposes
  state as **protobuf** types. The `.proto` file is the single source of
  truth — Kotlin codegen runs from a copy synced into the Android module at
  build time.
- `swift-android-bundler` builds `PokemonKit` (and its Swift dependencies)
  into per-architecture `.so` files plus a `swift-libs-manifest.json` that
  records the load order.
- The Android `swift-runtime` Gradle module loads the core Swift runtime
  libraries, binds libdispatch's main queue to the JVM main thread, and
  runs a high-frequency drain loop so `Task { @MainActor in ... }` and
  timers actually fire.
- The `pokemon-swift` Gradle module loads the `PokemonKit` `.so`, calls a
  Swift `nativeCreate` to spin up the view model, and forwards state
  updates as protobuf bytes back to Kotlin, where Compose renders them.

For more on the gradual-loading model, see [Android/README.md](Android/README.md).

## How this was built

This sample was produced by pair-programming with
[Claude Code](https://claude.com/claude-code) (Anthropic) — the entire
codebase was generated through an interactive session for demonstration
purposes. Treat it as a reference, not a production-ready starter: read it,
fork it, adapt it.

Not affiliated with or endorsed by Anthropic.
