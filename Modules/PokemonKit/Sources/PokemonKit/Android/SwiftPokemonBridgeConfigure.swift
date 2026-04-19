// SwiftPokemonBridgeConfigure.swift

#if os(Android)

import CSwiftJavaJNI
import FileSystemKit
import Foundation
@preconcurrency import SwiftJava

/// Stash the Context-derived Android paths into `AndroidAppDirectories` so any
/// Swift code can read them via `AndroidAppDirectories.default.<dir>` without
/// having to thread paths through every initializer.
///
/// Called from `PokemonSwiftRuntime.configure()` immediately after the product
/// `.so` is loaded and before `nativeCreate`. Can be invoked from any thread.
@_cdecl("Java_com_sample_pokemon_swift_SwiftPokemonBridge_nativeConfigure")
public func SwiftPokemonBridge_nativeConfigure(_ env: UnsafeMutablePointer<JNIEnv?>!,
                                                _ this: jobject,
                                                _ dataDir: jstring,
                                                _ filesDir: jstring,
                                                _ noBackupDir: jstring,
                                                _ cacheDir: jstring) {
    AndroidAppDirectories.configure(dataDir: URL(filePath: String(fromJNI: dataDir, in: env!)),
                                    filesDir: URL(filePath: String(fromJNI: filesDir, in: env!)),
                                    noBackupDir: URL(filePath: String(fromJNI: noBackupDir, in: env!)),
                                    cacheDir: URL(filePath: String(fromJNI: cacheDir, in: env!)))
}

#endif // os(Android)
