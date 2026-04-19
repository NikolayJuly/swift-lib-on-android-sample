// AsyncOperationsQueue.swift

import Swift

public actor AsyncOperationsQueue {

    public init() {}

    public typealias Operation = @Sendable () async -> Void

    public func add(_ operation: @escaping Operation) {
        queue.append(operation)
        Task {
            runNextOperationIfPossible()
        }
    }

    /// Add operation to queue, return only after operation was completed.
    public func addAndWait<R>(_ operation: @escaping @Sendable () async -> R) async -> R {
        return await withCheckedContinuation { continuation in
            let alteredOperation: @Sendable () async -> Void = {
                let r = await operation()
                continuation.resume(returning: r)
            }
            queue.append(alteredOperation)
            Task {
                runNextOperationIfPossible()
            }
        }
    }

    nonisolated
    public func syncAdd(_ operation: @escaping Operation) {
        Task.detached {
            await self.add(operation)
        }
    }

    // MARK: Private

    private var currentOperation: Operation?

    private var queue: [Operation] = []

    private func runNextOperationIfPossible() {
        guard currentOperation == nil else {
            return
        }

        guard queue.isEmpty == false else {
            return
        }

        let operation = queue.removeFirst()

        currentOperation = operation

        Task {
            await operation()
            currentOperation = nil
            runNextOperationIfPossible()
        }
    }
}
