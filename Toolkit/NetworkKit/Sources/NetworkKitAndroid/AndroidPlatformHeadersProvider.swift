//
//  AndroidPlatformHeadersProvider.swift
//  NetworkKit
//

#if os(Android)

import FoundationExtension
import NetworkKitAPI

public final class AndroidPlatformHeadersProvider: PlatformHeadersProvider {

    public let platformHeaders: [String: String]

    /// All values are passed in explicitly — no JNI calls inside.
    public init(deviceModel: String, appVersion: String, bundleId: String) {
        self.platformHeaders = [
            .platformHeaderName: RuntimeTargetPlatform.name,
            .deviceIdHeaderName: deviceModel,
            .appVersionHeaderName: appVersion,
            .bundleIdHeaderName: bundleId,
        ]
    }
}

#endif
