// RepositoryWithJsonCache.swift

import Dispatch
import FileSystemKit
import Foundation
import FoundationExtension
import Logging
import LoggingExtension

/// By design, this repository works correctly, only if there is only 1 repository exists at a time for each model
/// Otherwise we might get inconsistent data
public final class RepositoryWithJsonCache<Model: Codable & Sendable>: Sendable {

    @MainActor
    public var cachedModel: Model? {
        get {
            if initialLoadingIsCompleted == false {
                desperateInitialFetchOfCachedModel()
            }
            return observableCachedModel.wrappedValue
        }
        set { observableCachedModel.wrappedValue = newValue }
    }

    // TODO: Hide actual `Observed` behind the protocol
    let observableCachedModel: Observed<Model?> = .init(wrappedValue: nil)

    nonisolated
    public init(cacheLocation: CacheLocation,
                fileSystemService: FileSystemService = FileManager.default,
                logger: Logger) {
        self.cacheLocation = cacheLocation

        self.fileSystemService = fileSystemService
        self.logger = logger

        Task {
            await initialFetchOfCachedModel()
        }
    }

    // TODO: Remove `noasync` when package migrated to swift 6, looks like call to @MainActor enforced in swift6 even in non-async
    /// - note: main thread usage only
    @available(*, noasync, message: "Use async version of this function")
    @MainActor
    public func updateCache(with model: Model) {
        assert(Thread.isMainThread)

        // We will set cache here in sync manner, so if we call `cachedModel` right after this call, we will see these changes
        // It will help avoid awkward situation where we did update, but after this cached model still has old value
        // it might lead to multiple changes call, as we will repeat it right after this in async method
        self.cachedModel = model

        Task {
            do {
                try await updateCache(with: model)
            } catch {
                guard error.requireReporting else {
                    return
                }
                logger.recordIfNeeded(error)
            }
        }
    }

    nonisolated
    public func updateCache(with model: Model) async throws {
        await MainActor.run {
            self.cachedModel = model
        }

        let url = self.cacheLocation.cacheUrl
        try fileSystemService.createAllSubfolders(forFile: url, in: self.cacheLocation.appContainerFolderUrl)

        let encoder = Self.createEncoder()
        let data = try encoder.encode(model)

        try await fileSystemService.write(data: data, to: url)
        try? fileSystemService.excludeFromBackup(url)
    }

    /// Return task, which has current value or initial value after we completed loading it
    public var firstAvailableModelTask: Task<Model?, Never> {
        return Task { @MainActor in
            if initialLoadingIsCompleted || observableCachedModel.wrappedValue != nil {
                return cachedModel
            } else {
                return await withCheckedContinuation { continuation in
                    initialLoadingCompletions.append { [weak self] in
                        continuation.resume(returning: self?.cachedModel)
                    }
                }
            }
        }
    }

    /// This call might lead to raise condition or to still existed cache if called in wrong time
    public func debug_dropCache() async {
        await MainActor.run {
            self.cachedModel = nil
        }
        try? fileSystemService.removeItem(at: self.cacheLocation.cacheUrl)
    }

    // MARK: Private

    @MainActor
    private var initialLoadingIsCompleted = false

    @MainActor
    private var initialLoadingCompletions = [() -> Void]()

    private let cacheLocation: CacheLocation

    private let fileSystemService: FileSystemService
    private let logger: Logger

    nonisolated
    private static func createDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    nonisolated
    private static func createEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    @concurrent
    private func initialFetchOfCachedModel() async {
        assert(Thread.isMainThread == false)
        let model: Model? = readModelFromDisk()

        await handleInitialModelLoading(model)
    }

    @MainActor
    private func desperateInitialFetchOfCachedModel() {
        precondition(initialLoadingIsCompleted == false, "Should not call this method if we already loaded model")
        assertionFailure("We should never be here, we need to load model in advance before first read...")
        let error = SimpleError("We doing desperate fetch, even tho this is bad idea performance wise. Model type -\(Model.self)")
        logger.record(error)

        let model: Model? = readModelFromDisk()
        handleInitialModelLoading(model)
    }

    @MainActor
    private func handleInitialModelLoading(_ model: Model?) {
        initialLoadingIsCompleted = true
        if cachedModel == nil {
            cachedModel = model
        }
        initialLoadingCompletions.forEach { $0() }
        initialLoadingCompletions = []
    }

    private func readModelFromDisk() -> Model? {
        do {
            let url = cacheLocation.cacheUrl
            guard fileSystemService.fileExists(at: url) else {
                throw RepositoryWithJsonCacheErrors.noCachedFile
            }

            let jsonData = try self.fileSystemService.fileContent(at: url)
            let decoder = Self.createDecoder()
            return try decoder.decode(Model.self, from: jsonData)
        } catch {
            if error.requireReporting {
                self.logger.recordIfNeeded(error)
            }
            return nil
        }
    }
}

private enum RepositoryWithJsonCacheErrors: EnumError {
    case noCachedFile

    // MARK: EnumError
    static let typeDescription = "RepositoryWithJsonCache.Errors"
}

private extension Error {
    var requireReporting: Bool {
        guard let localErrors = self as? RepositoryWithJsonCacheErrors else {
            return true
        }

        switch localErrors {
        case .noCachedFile:
            return false
        }
    }
}

