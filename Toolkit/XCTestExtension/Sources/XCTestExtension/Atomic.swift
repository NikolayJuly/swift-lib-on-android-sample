// Atomic.swift

import Foundation

// FIXME: This is copy from FoundationExtension. If one day circular dependency will be allowed - remove this duplication
@propertyWrapper
final class Atomic<T>: @unchecked Sendable {

    @inlinable
    var wrappedValue: T {
        get {
            lock.lock()
            defer {
                lock.unlock()
            }
            return _wrappedValue
        }
        set {
            lock.lock()
            _wrappedValue = newValue
            lock.unlock()
        }
    }

    init(wrappedValue: T) {
        self._wrappedValue = wrappedValue
    }

    var projectedValue: Atomic { self }

    @discardableResult @inlinable
    func mutate<R>(_ mutation: (inout T) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        let r = try mutation(&_wrappedValue)
        return r
    }

    @inlinable
    func read<R>(_ read: (T) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        let r = try read(_wrappedValue)
        return r
    }

    // MARK: Internal

    @usableFromInline private(set) var _wrappedValue: T
    @usableFromInline let lock = NSLock()
}

extension Atomic where T == Int {
    @inlinable
    func increment(on amount: Int = 1) {
        mutate { $0 += amount }
    }

    @inlinable
    func decrement(on amount: Int = 1) {
        mutate { $0 -= 1 }
    }
}
