// PokemonInitializer.swift

#if os(Android)

import JsonCacheKit
import FileSystemKit
import Foundation
import Logging
import NetworkKit
import ObjectStorage
import PersistenceKit

struct PokemonAndroidDeviceInfo: Decodable {
    let modelRawName: String
    let appVersion: String
    let appIdentifier: String
}

/// Result of initialization — everything needed by @_cdecl methods.
/// `statesTask` is filled in after `subscribeStatesTask` wires up the AsyncSequence consumer.
struct InitializedPokemon: Sendable {
    let viewModel: PokemonViewModelImpl
    let bridgeRef: SwiftPokemonBridgeJava
    let logger: Logger
    var statesTask: Task<Void, Never>?
}

/// Fully synchronous pokemon initialization. Everything is ready when this returns.
/// Must be called on MainActor.
@MainActor
func initializePokemon(filesDirPath: String,
                       deviceInfoJson: String,
                       bridgeRef: SwiftPokemonBridgeJava) -> InitializedPokemon {

    let deviceInfoData = Data(deviceInfoJson.utf8)
    let deviceInfo = try! JSONDecoder().decode(PokemonAndroidDeviceInfo.self, from: deviceInfoData)

    // Logging: route every Swift log line through the Kotlin bridge.
    let logHandler = BridgeLogHandler(bridgeRef: bridgeRef)
    ObjectStorage.initLogger([logHandler])
    let logger = Logger(label: "PokemonKit")
    logger.info("[Pokemon] Initializing")

    // Shared singletons via ObjectStorage. JNI lifecycle @_cdecl look the observer up here.
    let storage = ObjectStorage.shared
    let lifecycleObserver = AndroidAppLifecycleObserver(logger: logger)
    storage.androidLifecycleObserver = lifecycleObserver

    // Platform deps for the VM.
    let platformHeadersProvider = AndroidPlatformHeadersProvider(deviceModel: deviceInfo.modelRawName,
                                                                  appVersion: deviceInfo.appVersion,
                                                                  bundleId: deviceInfo.appIdentifier)
    let apiLogger = Logger(label: "PokemonKit.Network")
    let apiClient = ApiClientAndroidImpl(platformHeadersProvider: platformHeadersProvider,
                                         logger: apiLogger)

    let fileSystem = FileManager.default
    let appContainerURL = URL(filePath: filesDirPath)
    let cacheURL = appContainerURL.appendingPathComponent("pokemon-cache.json", isDirectory: false)
    let cacheLocation = CacheLocation(cacheUrl: cacheURL, appContainerFolderUrl: appContainerURL)

    let kvURL = appContainerURL.appendingPathComponent("pokemon-kv.json", isDirectory: false)
    let keyValueStore = FileKeyValueStore(fileURL: kvURL, fileSystemService: fileSystem, logger: logger)

    let workingQueue = DispatchQueue(label: "com.sample.pokemon-cache", qos: .userInitiated)

    let viewModel = PokemonViewModelImpl(apiClient: apiClient,
                                         fileSystemService: fileSystem,
                                         keyValueStore: keyValueStore,
                                         cacheLocation: cacheLocation,
                                         workingQueue: workingQueue,
                                         appLifecycleObserver: lifecycleObserver,
                                         logger: logger)

    logger.info("[Pokemon] Initialized")

    return InitializedPokemon(viewModel: viewModel,
                              bridgeRef: bridgeRef,
                              logger: logger,
                              statesTask: nil)
}

private extension ObjectStorage {
    static let shared = ObjectStorage()
}

#endif // os(Android)
