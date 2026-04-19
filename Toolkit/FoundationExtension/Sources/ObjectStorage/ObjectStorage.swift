// ObjectStorage.swift

import FoundationExtension
import RunningEnvironment

public protocol ObjectStorageKey {
    associatedtype Value
}

public protocol ObjectStorageLockKey {}

public struct GenericObjectStorageKey<T>: ObjectStorageKey, ObjectStorageLockKey {
    public typealias Value = T
}

#if os(iOS) || os(Android)
@MainActor
#endif
public final class ObjectStorage {

    /// We might need different way of making it thread safe
    /// In iOS application we might prefer main thread usage, to simplify things
    /// In macOS cli apps, we do not init on main thread, and we can't use assert
    public enum ThreadSafeMechanism {
        case mainThread
        case locks

        public static var `default`: ThreadSafeMechanism {
            #if os(iOS)
                return .mainThread
            #else
                return .locks
            #endif
        }
    }

    public let threadSafeMechanism: ThreadSafeMechanism

    public init(threadSafeMechanism: ThreadSafeMechanism = .`default`) {
        self.threadSafeMechanism = threadSafeMechanism

#if DEBUG
        InstanceCounter.increment()
#endif // DEBUG
    }

    deinit {
#if DEBUG
        InstanceCounter.decrement()
#endif // DEBUG
    }

    @inlinable
    public subscript<Key: ObjectStorageKey>(_ key: Key.Type) -> Key.Value? {
        get {
            _lock()
            defer { _unlock() }
            guard let existed = storage[ObjectIdentifier(Key.self)] else {
                return nil
            }
            assert(existed is Key.Value, "Unexpected type. Expected \(Key.Value.self), but got \(type(of: existed))")
            return existed as? Key.Value
        }
        set {
            _lock()
            defer { _unlock() }
            storage[ObjectIdentifier(Key.self)] = newValue
        }
    }

    @inlinable
    public func contains<Key: ObjectStorageKey>(_ key: Key.Type) -> Bool {
        _lock()
        defer { _unlock() }
        return storage.keys.contains(ObjectIdentifier(Key.self))
    }

    @inlinable
    public func lock<Key: ObjectStorageLockKey>(_ key: Key.Type) -> PosixLock {
        _lock()
        defer { _unlock() }
        let objectIdentifier = ObjectIdentifier(Key.self)
        if let existed = locks[objectIdentifier] {
            return existed
        }
        let newOne = PosixLock()
        locks[objectIdentifier] = newOne
        return newOne
    }

    /// Invoke lock if threadSafeMechanism == .locks
    @inlinable
    @available(*, noasync, message: "Should not be used in async methods")
    public func lockIfNeeded<Key: ObjectStorageLockKey>(with key: Key.Type) {
        switch threadSafeMechanism {
        case .mainThread:
            assertMainThreadOrAppExtension()
        case .locks:
            let lock = lock(key)
            lock.lock()
        }
    }

    /// Invoke unlock if threadSafeMechanism == .locks
    @inlinable
    @available(*, noasync, message: "Should not be used in async methods")
    public func unlockIfNeeded<Key: ObjectStorageLockKey>(with key: Key.Type) {
        switch threadSafeMechanism {
        case .mainThread:
            break
        case .locks:
            let lock = lock(key)
            lock.unlock()
        }
    }

    public func withLock<R, Key: ObjectStorageLockKey>(key: Key.Type, _ block: () -> R) -> R {
        lockIfNeeded(with: key)
        defer { unlockIfNeeded(with: key) }
        return block()
    }

    // MARK: Private

    @usableFromInline
    internal var storage = [ObjectIdentifier: Any]()

    @usableFromInline
    internal var locks = [ObjectIdentifier: PosixLock]()

    @usableFromInline
    internal let itselfLock = PosixLock()

    @usableFromInline
    internal func _lock() {
        switch threadSafeMechanism {
        case .mainThread:
            assertMainThreadOrAppExtension()
        case .locks:
            itselfLock.lock()
        }
    }

    @usableFromInline
    internal func _unlock() {
        switch threadSafeMechanism {
        case .mainThread:
            break
        case .locks:
            itselfLock.unlock()
        }
    }
}

private actor InstanceCounter {

    nonisolated
    static func increment() {
        Task.detached {
            await self.shared.increment()
        }
    }

    nonisolated
    static func decrement() {
        Task.detached {
            await self.shared.decrement()
        }
    }

    nonisolated
    private static let shared = InstanceCounter()

    private var counter = 0

    private func increment() {
        counter += 1
        assert(counter == 1 || .isTesting, "We must have only 1 instance of it")
    }

    private func decrement() {
        counter -= 1
    }
}

#if os(macOS) || os(Linux)
extension ObjectStorage: @unchecked Sendable {}
#endif
