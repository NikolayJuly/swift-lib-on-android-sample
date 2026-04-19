// ObjectStorage+ApiClient.swift

import Foundation
import NetworkKitAPI
import ObjectStorage

#if canImport(Android)
import Logging
import NetworkKitAndroid
#else
import FoundationExtension
import NetworkKitFoundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif // canImport(FoundationNetworking)

#endif // canImport(FoundationNetworking)

public extension ObjectStorage {

    var platformHeadersProvider: PlatformHeadersProvider {
        get {
            if let res = self[PlatformHeadersProviderStorageKey.self] {
                return res
            }

            #if canImport(Android)
                fatalError("On Android, set platformHeadersProvider before using apiClient")
            #else
                let provider = ApplePlatformHeadersProvider()
                self[PlatformHeadersProviderStorageKey.self] = provider
                return provider
            #endif
        }
        set {
            self[PlatformHeadersProviderStorageKey.self] = newValue
        }
    }

    var apiClient: ApiClient {
        get {
            let keyType = ApiClientObjectStorageKey.self
            lockIfNeeded(with: keyType)
            defer {
                unlockIfNeeded(with: keyType)
            }

            if let existed = self[keyType] {
                return existed
            }

            assert(!.isTesting, "Set needed value for tests, do not use default")

            let newOne: ApiClient
            #if canImport(Android)
                newOne = ApiClientAndroidImpl(platformHeadersProvider: platformHeadersProvider,
                                              logger: logger)
            #else
                let config = URLSessionConfiguration.ephemeral
                config.urlCache = nil
                config.requestCachePolicy = .reloadIgnoringLocalCacheData

                newOne = ApiClientFoundationImpl(platformHeadersProvider: platformHeadersProvider,
                                                 configuration: config,
                                                 logger: logger)
            #endif
            self[keyType] = newOne
            return newOne
        }
        set {
            let keyType = ApiClientObjectStorageKey.self
            lockIfNeeded(with: keyType)
            defer {
                unlockIfNeeded(with: keyType)
            }

            self[keyType] = newValue
        }
    }
}

private struct PlatformHeadersProviderStorageKey: ObjectStorageKey {
    typealias Value = PlatformHeadersProvider
}

private struct ApiClientObjectStorageKey: ObjectStorageKey, ObjectStorageLockKey {
    typealias Value = ApiClient
}
