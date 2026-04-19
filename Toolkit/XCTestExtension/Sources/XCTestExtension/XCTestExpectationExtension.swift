// XCTestExpectationExtension.swift

import Foundation
import XCTest

public extension XCTestExpectation {
    convenience init(checkInterval: TimeInterval = 0.05,
                     predicate: @Sendable @escaping () -> Bool,
                     dispatchQueue: DispatchQueue,
                     description: String = "Periodic check expectation") {
        self.init(description: description)

        scheduleNextCheck(dispatchQueue: dispatchQueue, checkInterval: checkInterval, predicate: predicate)
    }

    convenience init(checkInterval: TimeInterval = 0.05,
                     predicate: @MainActor @Sendable @escaping () -> Bool,
                     description: String = "Periodic check expectation") {
        self.init(description: description)

        scheduleNextCheckAsync(checkInterval: checkInterval, predicate: predicate)

    }

    convenience init(checkInterval: TimeInterval = 0.05,
                     asyncPredicate: @Sendable @escaping () async -> Bool,
                     description: String = "Async periodic check expectation") {
        self.init(description: description)

        scheduleNextCheckWithAsyncPredicate(checkInterval: checkInterval, predicate: asyncPredicate)
    }

    convenience init(delay: TimeInterval = 0.05) {
        self.init(description: "Plain delay expectation")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.fulfill()
        }
    }

    // MARK: Private

    private func scheduleNextCheck(dispatchQueue: DispatchQueue,
                                   checkInterval: TimeInterval,
                                   predicate: @Sendable @escaping () -> Bool) {
        dispatchQueue.asyncAfter(deadline: .now() + checkInterval) { [weak self] in
            guard let self = self else { return }
            if predicate() {
                self.fulfill()
            } else {
                self.scheduleNextCheck(dispatchQueue: dispatchQueue, checkInterval: checkInterval, predicate: predicate)
            }
        }
    }

    private func scheduleNextCheckWithAsyncPredicate(checkInterval: TimeInterval,
                                                     predicate: @Sendable @escaping () async -> Bool) {
        let deadline = Date().addingTimeInterval(60) // safety limit
        Task { [weak self] in
            while Date() < deadline {
                guard let self else { return }
                if await predicate() {
                    self.fulfill()
                    return
                }
                try? await Task.sleep(nanoseconds: UInt64(Double(1_000_000_000) * checkInterval))
            }
        }
    }

    private func scheduleNextCheckAsync(checkInterval: TimeInterval,
                                        predicate: @MainActor @Sendable @escaping () -> Bool) {
        let deadline = Date().addingTimeInterval(60) // safety limit
        Task { @MainActor [weak self] in

            while Date() < deadline {
                guard let self else { return }
                if predicate() {
                    self.fulfill()
                    return
                }
                try? await Task.sleep(nanoseconds: UInt64(Double(1_000_000_000) * checkInterval))
            }
        }
    }
}
