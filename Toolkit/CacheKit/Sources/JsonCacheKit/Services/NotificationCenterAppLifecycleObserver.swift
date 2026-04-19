// NotificationCenterAppLifecycleObserver.swift

#if canImport(UIKit)

import Foundation
import UIKit

public final class NotificationCenterAppLifecycleObserver: AppLifecycleObserver, @unchecked Sendable {

    public init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    public func observeBecomingActive(_ handler: @escaping @MainActor @Sendable () -> Void) {
        notificationCenter.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                       object: nil,
                                       queue: nil) { _ in
            Task { @MainActor in handler() }
        }
    }

    public func observeEnteringBackground(_ handler: @escaping @MainActor @Sendable () -> Void) {
        notificationCenter.addObserver(forName: UIApplication.willResignActiveNotification,
                                       object: nil,
                                       queue: nil) { _ in
            Task { @MainActor in handler() }
        }
    }

    // MARK: - Private

    private let notificationCenter: NotificationCenter
}

#endif // canImport(UIKit)
