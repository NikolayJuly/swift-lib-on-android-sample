// BuildConfigurationProvider.swift

public protocol BuildConfigurationProvider: Sendable {
    var isNonAppStoreBuild: Bool { get }
}

#if !canImport(FoundationEssentials)

// If we see `FoundationEssentials` it means, we are in oss toolchain. Lets avoid full Foundation dependency

import Foundation

public let defaultBuildConfigurationProvider = Bundle.main

extension Bundle: BuildConfigurationProvider {
    @inlinable
    public var isNonAppStoreBuild: Bool { _isNonAppStoreBuild }
}

@usableFromInline
let _isNonAppStoreBuild: Bool = {
    guard Bool.isInDebug == false else {
        return true
    }

    guard let url = Bundle.main.appStoreReceiptURL else {
        return false
    }
    return url.absoluteString.contains("sandboxReceipt")
}()

#else // !canImport(FoundationEssentials)

import FoundationEssentials

public let defaultBuildConfigurationProvider = DummyBuildConfigurationProvider()

public struct DummyBuildConfigurationProvider: BuildConfigurationProvider {
    public let isNonAppStoreBuild: Bool = false
    public init() {}
}

#endif // !canImport(FoundationEssentials)


