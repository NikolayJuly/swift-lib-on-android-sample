// AccessControlPropertyWrapper.swift

import Foundation

@propertyWrapper
public struct AccessControl<T> {

    /// Assuming mainThread access control, named this way for nicer API usage
    public init(wrappedValue: T) {
        self._wrappedValue = wrappedValue
        self._accessControl = { assert(Thread.isMainThread) }
    }

    public init(wrappedValue: T, accessControl: @escaping () -> Void) {
        self._wrappedValue = wrappedValue
        self._accessControl = accessControl
        //self._didSetAction = didSetAction
    }

    @inlinable
    public var wrappedValue: T {
        get {
            _accessControl()
            return _wrappedValue
        }
        set {
            _accessControl()
            _wrappedValue = newValue
        }
    }

    // MARK: Internal
    @usableFromInline
    internal var _wrappedValue: T

    @usableFromInline
    internal let _accessControl: () -> Void
}

