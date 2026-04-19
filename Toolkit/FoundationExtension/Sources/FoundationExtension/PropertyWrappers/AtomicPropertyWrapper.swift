// AtomicPropertyWrapper.swift

import Foundation

@propertyWrapper
public final class Atomic<T>: @unchecked Sendable {

    @inlinable
    public var wrappedValue: T {
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

    public init(_ t: T) {
        self._wrappedValue = t
    }

    public init(wrappedValue: T) {
        self._wrappedValue = wrappedValue
    }

    public var projectedValue: Atomic { self }

    @discardableResult @inlinable
    public func mutate<R>(_ mutation: (inout T) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        let r = try mutation(&_wrappedValue)
        return r
    }

    @inlinable
    public func read<R>(_ read: (T) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        let r = try read(_wrappedValue)
        return r
    }

    // MARK: Internal

    @usableFromInline private(set) var _wrappedValue: T
    @usableFromInline let lock = PosixLock()
}

public extension Atomic where T == Int {
    @inlinable
    func increment(on amount: Int = 1) {
        mutate { $0 += amount }
    }

    @inlinable
    func decrement(on amount: Int = 1) {
        mutate { $0 -= 1 }
    }
}

public extension Atomic where T: RangeReplaceableCollection {
    @inlinable
    func append(_ element: T.Element) {
        mutate { $0.append(element) }
    }

    @inlinable
    func append(contentsOf sequence: any Sequence<T.Element>) {
        mutate { $0.append(contentsOf: sequence) }
    }
}

extension Atomic: ExpressibleByBooleanLiteral where T == Bool {

    public typealias BooleanLiteralType = Bool

    public convenience init(booleanLiteral value: Bool) {
        self.init(value)
    }
}

extension Atomic: ExpressibleByIntegerLiteral where T == Int {
    public typealias IntegerLiteralType = Int

    public convenience init(integerLiteral value: Int) {
        self.init(value)
    }
}

extension Atomic: ExpressibleByArrayLiteral where T: RangeReplaceableCollection {
    public typealias ArrayLiteralElement = T.Element

    public convenience init(arrayLiteral elements: T.Element...) {
        let t = T(elements)
        self.init(t)
    }
}

public extension Atomic {
    convenience init<K>() where T == Optional<K> {
        self.init(nil)
    }
}
