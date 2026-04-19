// KeyValueStore.swift

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public protocol KeyValueStore: AnyObject, Sendable {
    func double(forKey key: String) -> Double

    func set(_ value: Double, forKey key: String)
}

#if !os(Android)
import Foundation

// `UserDefaults` is thread safe.
// And according to this post - `https://forums.developer.apple.com/forums/thread/757527?answerId=792408022#792408022`
// only reason to hide Sendable is subclassing
extension UserDefaults: @retroactive @unchecked Sendable {}

extension UserDefaults: KeyValueStore {}
#endif // !os(Android)
