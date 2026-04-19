// AndroidAppLifecycleObserver.swift

#if os(Android)

import Logging
import ObjectStorage
import Synchronization

/// Android-specific implementation of `AppLifecycleObserver`.
///
/// Stores handlers registered by consumers (e.g., `ServiceWithJsonCacheImpl`) and
/// fires them when the Kotlin side invokes the corresponding JNI bridge functions
/// — those live in a per-feature Android bridge (e.g., `PokemonBridge`) and
/// call `fireBecameActive()` / `fireEnteredBackground()` here.
public final class AndroidAppLifecycleObserver: AppLifecycleObserver, Sendable {

    public init(logger: Logger) {
        self.logger = logger
    }

    // MARK: - AppLifecycleObserver

    public func observeBecomingActive(_ handler: @escaping @MainActor @Sendable () -> Void) {
        activeHandlers.withLock { $0.append(handler) }
    }

    public func observeEnteringBackground(_ handler: @escaping @MainActor @Sendable () -> Void) {
        backgroundHandlers.withLock { $0.append(handler) }
    }

    // MARK: - Fired from JNI bridge

    @MainActor
    public func fireBecameActive() {
        let handlers = activeHandlers.withLock { $0 }
        logger.info("[AndroidLifecycle] fireBecameActive, \(handlers.count) handler(s)")
        for handler in handlers {
            handler()
        }
    }

    @MainActor
    public func fireEnteredBackground() {
        let handlers = backgroundHandlers.withLock { $0 }
        logger.info("[AndroidLifecycle] fireEnteredBackground, \(handlers.count) handler(s)")
        for handler in handlers {
            handler()
        }
    }

    // MARK: - Private

    private let logger: Logger
    private let activeHandlers = Mutex<[@MainActor @Sendable () -> Void]>([])
    private let backgroundHandlers = Mutex<[@MainActor @Sendable () -> Void]>([])
}

public extension ObjectStorage {
    /// Shared lifecycle observer used by JNI bridges and Swift consumers on Android.
    /// Must be set during native init before any consumer reads it.
    var androidLifecycleObserver: AndroidAppLifecycleObserver {
        get {
            guard let existed = self[AndroidLifecycleObserverKey.self] else {
                fatalError("AndroidAppLifecycleObserver must be set during native init")
            }
            return existed
        }
        set {
            self[AndroidLifecycleObserverKey.self] = newValue
        }
    }
}

private struct AndroidLifecycleObserverKey: ObjectStorageKey {
    typealias Value = AndroidAppLifecycleObserver
}

#endif // os(Android)
