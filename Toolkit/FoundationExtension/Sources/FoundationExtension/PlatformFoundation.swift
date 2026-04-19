// PlatformFoundation.swift

#if canImport(FoundationEssentials)
@_exported import FoundationEssentials
#else
@_exported import Foundation
#endif

public enum RuntimeTargetPlatform {
    public static var name: String {
        #if os(Android)
            "Android"
        #elseif os(Linux)
            "Linux"
        #elseif os(iOS)
            "iOS"
        #elseif os(macOS)
            "macOS"
        #elseif os(tvOS)
            "tvOS"
        #elseif os(watchOS)
            "watchOS"
        #elseif os(visionOS)
            "visionOS"
        #elseif os(Windows)
            "Windows"
        #else
            "Unknown"
    #endif
    }
}
