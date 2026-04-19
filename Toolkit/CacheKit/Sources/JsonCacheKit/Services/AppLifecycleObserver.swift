// AppLifecycleObserver.swift

/// Abstraction over app lifecycle events.
/// On iOS backed by `NotificationCenter` (`UIApplication.didBecomeActive/willResignActive`),
/// on Android — by Activity lifecycle callbacks bridged through JNI into
/// `AndroidAppLifecycleObserver`.
public protocol AppLifecycleObserver: Sendable {

    /// Register a handler invoked when the app becomes active/foreground.
    /// Use to resume network activity (e.g., trigger a cache refresh).
    func observeBecomingActive(_ handler: @escaping @MainActor @Sendable () -> Void)

    /// Register a handler invoked when the app is entering background/inactive state.
    /// Use to flush pending work (e.g., persist or upload queued data).
    func observeEnteringBackground(_ handler: @escaping @MainActor @Sendable () -> Void)
}
