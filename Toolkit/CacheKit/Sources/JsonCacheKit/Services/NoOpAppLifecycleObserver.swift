// NoOpAppLifecycleObserver.swift

/// No-op implementation. Useful as the default when a consumer doesn't want
/// any automatic lifecycle-driven behavior, and in tests.
public final class NoOpAppLifecycleObserver: AppLifecycleObserver {

    public init() {}

    public func observeBecomingActive(_ handler: @escaping @MainActor @Sendable () -> Void) {}

    public func observeEnteringBackground(_ handler: @escaping @MainActor @Sendable () -> Void) {}
}
