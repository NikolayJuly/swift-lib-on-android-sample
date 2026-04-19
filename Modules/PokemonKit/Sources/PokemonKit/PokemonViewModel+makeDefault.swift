// PokemonViewModel+makeDefault.swift

#if canImport(UIKit)

import JsonCacheKit
import FileSystemKit
import Foundation
import Logging
import NetworkKit
import PersistenceKit

public extension PokemonViewModelImpl {
    /// Convenience composition root for Apple platforms. Wires a URLSession-based
    /// `ApiClient`, `FileManager`, `UserDefaults`, and a dedicated working queue
    /// into a ready-to-use `PokemonViewModel`.
    @MainActor
    static func makeDefault() -> PokemonViewModelImpl {
        let apiLogger = Logger(label: "PokemonKit.Network")
        let apiClient = ApiClientFoundationImpl(platformHeadersProvider: ApplePlatformHeadersProvider(),
                                                logger: apiLogger)
        let fileSystem = FileManager.default
        let keyValueStore = UserDefaults.standard
        let cacheLocation = CacheLocation.create(for: "pokemon-cache", using: fileSystem)
        let workingQueue = DispatchQueue(label: "com.sample.pokemon-cache", qos: .userInitiated)
        let appLifecycleObserver = NotificationCenterAppLifecycleObserver()
        let logger = Logger(label: "PokemonKit")
        return PokemonViewModelImpl(apiClient: apiClient,
                                    fileSystemService: fileSystem,
                                    keyValueStore: keyValueStore,
                                    cacheLocation: cacheLocation,
                                    workingQueue: workingQueue,
                                    appLifecycleObserver: appLifecycleObserver,
                                    logger: logger)
    }
}

#endif
