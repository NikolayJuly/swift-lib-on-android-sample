// ServiceWithJsonCache.swift

import FileSystemKit
import Foundation
import FoundationExtension
import Logging
import LoggingExtension
import NetworkKit

// TODO: Consider 2 models - one thread save with Lock other main thread only.
//       Observations only form non-main thread, to leave main thread only for UI

/// This service fetch model from server and keep cached copy locally
public protocol ServiceWithJsonCache<Model>: Sendable {
    associatedtype Model: Codable & Equatable & Sendable

    var observableModel: any AnyDistinctObserved<Model?> { get }

    /// Trigger request to API to fetch latest model
    func updateModelFromNetwork()
}

public extension ServiceWithJsonCache {
    @MainActor
    var cachedModel: Model? {
        observableModel.value
    }
}

public final class AnyServiceWithJsonCache<M: Codable & Equatable>: ServiceWithJsonCache {

    public typealias Model = M

    public init<S: ServiceWithJsonCache>(_ other: S) where S.Model == M {
        self.observableModel = other.observableModel
        self.updateModelFromNetworkBlock = other.updateModelFromNetwork
    }

    public let observableModel: any AnyDistinctObserved<Model?>

    public func updateModelFromNetwork() {
        updateModelFromNetworkBlock()
    }

    // MARK: Private

    private let updateModelFromNetworkBlock: @Sendable () -> Void
}

/// By design, this service works correctly, there is only one exists at a time. And there should not be other repository apart one which passed inside
public final class ServiceWithJsonCacheImpl<M: Codable & Sendable & Equatable, RF: RequestFactory>: ServiceWithJsonCache where RF.Request.ResponseType == JSONDecodableResponse<M>, RF: Sendable {

    // MARK: ServiceWithJsonCache

    public typealias Model = M
    public typealias RequestFactory =  RF

    @MainActor
    public var cachedModel: Model? { repository.cachedModel }

    public var observableModel: any AnyDistinctObserved<Model?> { repository.observableCachedModel }

    public convenience init(workingQueue: DispatchQueue,
                            cacheLocation: CacheLocation,
                            requestFactory: RequestFactory,
                            apiClient: ApiClient,
                            fileSystemService: FileSystemService = FileManager.default,
                            appLifecycleObserver: AppLifecycleObserver = NoOpAppLifecycleObserver(),
                            logger: Logger) {

        let repository = RepositoryWithJsonCache<Model>(cacheLocation: cacheLocation,
                                                        fileSystemService: fileSystemService,
                                                        logger: logger)
        self.init(repository: repository,
                  requestFactory: requestFactory,
                  apiClient: apiClient,
                  workingQueue: workingQueue,
                  appLifecycleObserver: appLifecycleObserver,
                  logger: logger)
    }

    public init(repository: RepositoryWithJsonCache<Model>,
                requestFactory: RequestFactory,
                apiClient: ApiClient,
                workingQueue: DispatchQueue,
                appLifecycleObserver: AppLifecycleObserver = NoOpAppLifecycleObserver(),
                logger: Logger) {
        self.repository = repository
        self.apiClient = apiClient
        self.logger = logger
        self.requestFactory = requestFactory
        self.workingQueue = workingQueue

        self._currentTask = AccessControl<TaskType?>(wrappedValue: nil, accessControl: { dispatchPrecondition(condition: .onQueue(workingQueue)) })

        appLifecycleObserver.observeBecomingActive { [weak self] in
            self?.updateModelFromNetwork()
        }
        updateModelFromNetwork()
    }

    /// This call might lead to raise condition or to still existed cache if called in wrong time
    public func debug_dropCacheAndStopRequest() async {
        await workingQueue.execute {
            self._currentTask.wrappedValue?.cancel()
            self._currentTask.wrappedValue = nil
        }
        await repository.debug_dropCache()
    }

    public func updateModelFromNetwork() {
        workingQueue.async {
            self._currentTask.wrappedValue?.cancel()
            self._currentTask.wrappedValue = nil

            self._currentTask.wrappedValue = Task {
                let request = self.requestFactory.make()
                do {
                    let decodableResponse = try await self.apiClient.request(request)
                    let response = decodableResponse.response
                    try? await self.repository.updateCache(with: response)
                } catch {
                    if error.isCancelled && Task.isCancelled {
                        self.logger.info("ServiceWithJsonCache :: Request for \(Model.self) cancelled due to a newer update request")
                    } else if error.isGeneralNetworkError == false {
                        let simpleError = SimpleError("Failed to retrieve data from network: Model = \(Model.self). Original error - \(error)")
                        self.logger.record(simpleError)
                    } else {
                        self.logger.info("ServiceWithJsonCache :: Got error while updating \(Model.self): \(error)")
                    }
                }
            }
        }
    }

    // MARK: Private

    private let requestFactory: RequestFactory
    private let repository: RepositoryWithJsonCache<Model>
    private let apiClient: ApiClient
    private let logger: Logger
    private let workingQueue: DispatchQueue

    private typealias TaskType = Task<Void, Never>

    // AccessControl for now will allow us to check, that we use it on right queue. May be later there will be generic isolation check to GlobalActor
    nonisolated(unsafe)
    private var _currentTask: AccessControl<TaskType?>
}

extension ServiceWithJsonCacheImpl: Sendable {}
