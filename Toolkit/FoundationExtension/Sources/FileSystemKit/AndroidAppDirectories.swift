// AndroidAppDirectories.swift

#if os(Android)

import Synchronization

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Holds the Android `Context`-derived application directory URLs.
///
/// On Android, app directories depend on the current user (work profile,
/// secondary user, guest, etc.) and must come from `Context` — they cannot
/// be hardcoded as `/data/user/0/<pkg>`. The Kotlin runtime layer is
/// expected to read all four from `Context` and pass them via JNI before
/// any Swift code touches the file system.
///
/// From Kotlin (e.g. `PokemonSwiftRuntime.configure()`):
/// ```kotlin
/// bridge.nativeConfigure(
///     dataDir = context.dataDir.absolutePath,
///     filesDir = context.filesDir.absolutePath,
///     noBackupDir = context.noBackupFilesDir.absolutePath,
///     cacheDir = context.cacheDir.absolutePath,
/// )
/// ```
/// From Swift JNI bridge:
/// ```swift
/// AndroidAppDirectories.configure(dataDir: ...,
///                                 filesDir: ...,
///                                 noBackupDir: ...,
///                                 cacheDir: ...)
/// ```
public struct AndroidAppDirectories: Sendable {

    /// Root of the app's data directory. Equivalent to `Context.getDataDir()`.
    /// Example: `/data/user/<N>/<pkg>`.
    public let dataDir: URL

    /// User files directory. Equivalent to `Context.getFilesDir()`.
    /// Example: `/data/user/<N>/<pkg>/files`.
    public let filesDir: URL

    /// "No backup" files directory. Equivalent to `Context.getNoBackupFilesDir()`.
    /// Example: `/data/user/<N>/<pkg>/no_backup`.
    public let noBackupDir: URL

    /// Cache directory. Equivalent to `Context.getCacheDir()`.
    /// Example: `/data/user/<N>/<pkg>/cache`.
    public let cacheDir: URL

    public static func configure(dataDir: URL,
                                 filesDir: URL,
                                 noBackupDir: URL,
                                 cacheDir: URL) {
        let dirs = AndroidAppDirectories(dataDir: dataDir,
                                         filesDir: filesDir,
                                         noBackupDir: noBackupDir,
                                         cacheDir: cacheDir)
        _override.withLock { $0 = dirs }
    }

    public static var `default`: AndroidAppDirectories {
        guard let dirs = _override.withLock({ $0 }) else {
            fatalError("""
                AndroidAppDirectories is not configured.
                Call AndroidAppDirectories.configure(...) before any FS access.

                From Kotlin (PokemonSwiftRuntime.configure()):
                    bridge.nativeConfigure(
                        dataDir = context.dataDir.absolutePath,
                        filesDir = context.filesDir.absolutePath,
                        noBackupDir = context.noBackupFilesDir.absolutePath,
                        cacheDir = context.cacheDir.absolutePath,
                    )
                From Swift JNI entry point:
                    AndroidAppDirectories.configure(dataDir: ...,
                                                    filesDir: ...,
                                                    noBackupDir: ...,
                                                    cacheDir: ...)
                """)
        }
        return dirs
    }

    // MARK: - Private

    private static let _override = Mutex<AndroidAppDirectories?>(nil)
}

#endif // os(Android)
