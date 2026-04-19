//
//  PlatformHeadersProvider.swift
//  NetworkKit
//

/// Provides platform-specific HTTP headers (device model, app version, bundle ID, etc.)
/// that are added to every request by `ApiClient` implementations.
///
/// Implementations should cache the headers in `init` to avoid repeated calls
/// to `Bundle.main`, `UIDevice`, or JNI on Android.
public protocol PlatformHeadersProvider: Sendable {
    var platformHeaders: [String: String] { get }
}

/// For server-side / backend API clients that don't need platform headers.
public struct EmptyPlatformHeadersProvider: PlatformHeadersProvider {
    public let platformHeaders: [String: String] = [:]
    public init() {}
}
