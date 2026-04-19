// SwiftPokemonBridge.swift

#if os(Android)

import CSwiftJavaJNI
import JsonCacheKit
import Foundation
import FoundationExtension
import Logging
import ObjectStorage
@preconcurrency import SwiftJava
import Synchronization

// MARK: - Swift → Kotlin (callbacks via @JavaMethod)

/// Swift-side declaration of the Kotlin class, used to call Kotlin methods
/// from Swift (push state snapshots, push logs).
@JavaClass("com.sample.pokemon.swift.SwiftPokemonBridge")
package struct SwiftPokemonBridgeJava {
    /// Pushed on every new state from the VM. Payload is `PB_PokemonListState` protobuf bytes.
    @JavaMethod
    public func onStateUpdate(_ bytes: [Int8])

    @JavaMethod
    public func logMessage(_ message: String)

    @JavaMethod
    public func logError(_ source: String, _ message: String)
}

// MARK: - State

/// Thread-safe storage for initialized Pokemon VM.
/// Set once in nativeCreate (synchronously), read by all other methods.
private let initializedPokemon = Mutex<InitializedPokemon?>(nil)

// MARK: - Kotlin → Swift (native methods via @_cdecl)

/// Fully synchronous — everything is ready when this returns.
/// Must be called on Main thread, before any other native method.
@_cdecl("Java_com_sample_pokemon_swift_SwiftPokemonBridge_nativeCreate")
public func SwiftPokemonBridge_nativeCreate(_ env: UnsafeMutablePointer<JNIEnv?>!,
                                             _ this: jobject,
                                             _ filesDir: jstring,
                                             _ deviceInfoJson: jstring) {
    let bridge = SwiftPokemonBridgeJava(javaThis: this, environment: env!)
    nonisolated(unsafe) let bridgeRef = bridge

    let filesDirPath = String(fromJNI: filesDir, in: env!)
    let deviceInfo = String(fromJNI: deviceInfoJson, in: env!)

    MainActor.assumeIsolated {
        var result = initializePokemon(filesDirPath: filesDirPath,
                                       deviceInfoJson: deviceInfo,
                                       bridgeRef: bridgeRef)

        // Subscribe to state updates and forward them to Kotlin as protobuf bytes.
        // The AsyncStream yields the current state immediately on subscribe, so
        // Kotlin gets the initial snapshot without needing a separate "get" method.
        let viewModel = result.viewModel
        result.statesTask = Task { @MainActor in
            for await state in viewModel.states() {
                do {
                    let data = try state.serializedData()
                    let bytes = [Int8](unsafeUninitializedCapacity: data.count) { buffer, initialized in
                        data.withUnsafeBytes { raw in
                            buffer.baseAddress!.withMemoryRebound(to: UInt8.self, capacity: raw.count) { out in
                                _ = raw.copyBytes(to: UnsafeMutableBufferPointer(start: out, count: raw.count))
                            }
                        }
                        initialized = data.count
                    }
                    bridgeRef.onStateUpdate(bytes)
                } catch {
                    result.logger.record(error)
                }
            }
        }
        initializedPokemon.withLock { $0 = result }
    }
}

/// Main thread, after nativeCreate.
@_cdecl("Java_com_sample_pokemon_swift_SwiftPokemonBridge_nativeRefresh")
public func SwiftPokemonBridge_nativeRefresh(_ env: UnsafeMutablePointer<JNIEnv?>!,
                                              _ this: jobject) {
    guard let state = initializedPokemon.withLock({ $0 }) else {
        fatalError("nativeCreate must be called first")
    }
    MainActor.assumeIsolated {
        state.viewModel.refresh()
    }
}

/// Main thread, after nativeCreate.
@_cdecl("Java_com_sample_pokemon_swift_SwiftPokemonBridge_nativeOnBecameActive")
public func SwiftPokemonBridge_nativeOnBecameActive(_ env: UnsafeMutablePointer<JNIEnv?>!,
                                                     _ this: jobject) {
    MainActor.assumeIsolated {
        ObjectStorage.shared.androidLifecycleObserver.fireBecameActive()
    }
}

/// Main thread, after nativeCreate.
@_cdecl("Java_com_sample_pokemon_swift_SwiftPokemonBridge_nativeOnEnteredBackground")
public func SwiftPokemonBridge_nativeOnEnteredBackground(_ env: UnsafeMutablePointer<JNIEnv?>!,
                                                          _ this: jobject) {
    MainActor.assumeIsolated {
        ObjectStorage.shared.androidLifecycleObserver.fireEnteredBackground()
    }
}

private extension ObjectStorage {
    static let shared = ObjectStorage()
}

#endif // os(Android)
