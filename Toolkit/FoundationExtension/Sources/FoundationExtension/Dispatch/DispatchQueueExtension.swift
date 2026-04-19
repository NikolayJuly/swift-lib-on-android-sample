// DispatchQueueExtension.swift

import Dispatch

public extension DispatchQueue {
    func execute<T>(_ closure: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            self.async {
                let t = closure()
                continuation.resume(returning: t)
            }
        }
    }

    func execute<T>(_ closure: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            self.async {
                do {
                    let t = try closure()
                    continuation.resume(returning: t)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
