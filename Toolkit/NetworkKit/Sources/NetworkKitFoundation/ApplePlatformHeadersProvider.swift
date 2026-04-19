//
//  ApplePlatformHeadersProvider.swift
//  NetworkKit
//

import Foundation
import FoundationExtension
import NetworkKitAPI

#if canImport(UIKit)
    import UIKit
#endif

public final class ApplePlatformHeadersProvider: PlatformHeadersProvider {

    public let platformHeaders: [String: String]

    public init() {
        var res: [String: String] = [.platformHeaderName: RuntimeTargetPlatform.name]

        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
            if let version: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                res[.appVersionHeaderName] = version
            }

            if let bundleID = Bundle.main.bundleIdentifier {
                res[.bundleIdHeaderName] = bundleID
            }
        #endif

        #if os(iOS)
            res[.deviceIdHeaderName] = UIDevice.modelRawName
        #else
            res[.deviceIdHeaderName] = "NonIos"
        #endif

        self.platformHeaders = res
    }
}
