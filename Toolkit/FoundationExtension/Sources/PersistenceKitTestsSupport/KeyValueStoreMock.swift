// KeyValueStoreMock.swift

import Foundation
import FoundationExtension
import PersistenceKit

// Will use `@unchecked Sendable` just to silence compiler for now.
public final class KeyValueStoreMock: KeyValueStore, @unchecked /*not at all*/ Sendable {

    @Atomic
    public var doubleMap = [String: Double]()

    public init() {}

    public func double(forKey key: String) -> Double {
        return doubleMap[key] ?? 0
    }

    public func set(_ value: Double, forKey key: String) {
        doubleMap[key] = value
    }
}
