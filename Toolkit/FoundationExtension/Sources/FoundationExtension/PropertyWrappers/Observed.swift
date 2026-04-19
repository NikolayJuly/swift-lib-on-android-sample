// Observed.swift

import Dispatch
import Foundation
import RunningEnvironment

public final class ObservedSubscription: Hashable, Sendable {
    public static func == (lhs: ObservedSubscription, rhs: ObservedSubscription) -> Bool {
        return lhs.uuid == rhs.uuid
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }

    public init(uuid: UUID = UUID()) {
        self.uuid = uuid
    }

    // MARK: Private

    fileprivate let uuid: UUID
}

public struct ObservedChange<T> {
    public let oldValue: T
    public let newValue: T
}

extension ObservedChange: Sendable where T: Sendable {}

public protocol AnyObserved<Value>: Sendable, AnyObject {
    associatedtype Value
    typealias Change = ObservedChange<Value>
    typealias Update = @MainActor (Change) -> Void

    @MainActor
    var value: Value { get }

    @discardableResult @MainActor
    func subscribe(_ update: @escaping Update) -> ObservedSubscription

    @MainActor
    func unsubscribe(_ subscription: ObservedSubscription?)
}

public protocol AnyDistinctObserved<Value>: AnyObserved where Value: Equatable {
    /// This method will always trigger `update` with current value, because, value might have changed between function call and subscription actually established
    @discardableResult nonisolated
    func subscribeForChangesOnlyAsync(_ update: @escaping Update) -> ObservedSubscription

    @discardableResult @MainActor
    func subscribeForChangesOnly(triggerUpdateWithInitialValue: Bool, _ update: @escaping Update) -> ObservedSubscription
}

public extension AnyObserved {
    nonisolated
    func unsubscribeAsync(_ subscription: ObservedSubscription?) {
        Task { @MainActor [self] in
            self.unsubscribe(subscription)
        }
    }
}

public extension AnyDistinctObserved {
    /// This method not gonna trigger update with initial value
    @discardableResult @MainActor
    func subscribeForChangesOnly(_ update: @escaping Update) -> ObservedSubscription {
        subscribeForChangesOnly(triggerUpdateWithInitialValue: false, update)
    }
}

@propertyWrapper
public final class Observed<T>: AnyObserved, Sendable {

    public typealias Value = T

    public var projectedValue: Observed<T> { self }

    @MainActor
    public var value: Value { wrappedValue }

    @MainActor
    public var wrappedValue: T {
        get {
            accessControl()
            return _wrappedValue
        }
        set {
            accessControl()
            let oldValue = _wrappedValue
            _wrappedValue = newValue
            updateSubscribers(from: oldValue, to: newValue)
        }
    }

    public init(wrappedValue: T) {
        self._wrappedValue = wrappedValue
        self.accessControl = { assertMainThread() }
    }

    public init(_ t: T) {
        self._wrappedValue = t
        self.accessControl = { assertMainThread() }
    }

    /// Subscribe to changes, no initial call will be made, which mean all initial action on changes, should be done manually
    /// - parameter dispatchQueue: queue where we get changes in async manner.
    ///                            if nil, initial call happen immediately, changes happen on callers queue
    /// - parameter update: block which will be called on every change, even if we change to itself. If no need to change on itself, consider other method with `Equitable` requirement
    @discardableResult @MainActor
    public func subscribe(_ update: @escaping Update) -> ObservedSubscription {
        accessControl()

        let subscription = ObservedSubscription(uuid: UUID())
        observers[subscription] = update

        return subscription
    }

    @MainActor
    public func unsubscribe(_ subscription: ObservedSubscription?) {
        guard let subscription else { return }
        self.observers[subscription] = nil
    }

    /// - returns: old value
    @MainActor @discardableResult
    public func update(_ newVale: T) -> T {
        let oldValue = wrappedValue
        self.wrappedValue = newVale
        return oldValue
    }

    // MARK: Tests support

    /// This setter bypass subscribers notification
    internal func test_setWrappedValue(_ value: T) {
        precondition(.isTesting)
        self._wrappedValue = value
    }

    // MARK: Private

    // Any actual access and modifier of it, marked with @MainActor
    nonisolated(unsafe)
    private var _wrappedValue: T

    private let accessControl: @Sendable () -> Void

    @MainActor
    private func updateSubscribers(from oldValue: T, to newValue: T) {
        let updates = observers.values
        for update in updates {
            let change = Change(oldValue: oldValue, newValue: newValue)
            update(change)
        }
    }

    @MainActor
    private var observers: [ObservedSubscription: Update] = [:]
}

extension Observed: AnyDistinctObserved where T: Equatable {
    @discardableResult nonisolated
    public func subscribeForChangesOnlyAsync(_ update: @escaping Update) -> ObservedSubscription {

        let subscription = ObservedSubscription(uuid: UUID())

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.observers[subscription] = { change in
                guard change.oldValue != change.newValue else {
                    return
                }
                update(change)
            }

            let change = Change(oldValue: wrappedValue, newValue: wrappedValue)
            update(change)
        }

        return subscription
    }

    @discardableResult @MainActor
    public func subscribeForChangesOnly(triggerUpdateWithInitialValue: Bool = false,
                                        _ update: @escaping Update) -> ObservedSubscription {

        let subscription = self.subscribe { change in
            guard change.oldValue != change.newValue else {
                return
            }
            update(change)
        }

        if triggerUpdateWithInitialValue {
            let change = Change(oldValue: wrappedValue, newValue: wrappedValue)
            update(change)
        }

        return subscription
    }
}
