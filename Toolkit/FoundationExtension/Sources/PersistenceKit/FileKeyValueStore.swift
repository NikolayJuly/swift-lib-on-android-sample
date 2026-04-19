// FileKeyValueStore.swift

#if canImport(Synchronization)

import FileSystemKit
import FoundationExtension
import Logging
import Synchronization

@available(iOS 18.0, macOS 15.0, *)
public final class FileKeyValueStore: KeyValueStore {

    public init(fileURL: URL, fileSystemService: FileSystemService, logger: Logger) {
        self.fileURL = fileURL
        self.fileSystemService = fileSystemService
        self.logger = logger
        self.state = Mutex(Self.load(from: fileURL, using: fileSystemService))
    }

    public func double(forKey key: String) -> Double {
        state.withLock { $0[key] ?? 0 }
    }

    public func set(_ value: Double, forKey key: String) {
        state.withLock { $0[key] = value }
        schedulePersist()
    }

    // MARK: - Private

    private let fileURL: URL
    private let fileSystemService: FileSystemService
    private let logger: Logger
    private let state: Mutex<[String: Double]>
    private let writeQueue = AsyncOperationsQueue()

    private func schedulePersist() {
        writeQueue.syncAdd { [weak self] in
            guard let self else { return }
            do {
                let snapshot = self.state.withLock { $0 }
                let encoded = try JSONEncoder().encode(snapshot)
                try await self.fileSystemService.write(data: encoded, to: self.fileURL)
            } catch {
                self.logger.info("FileKeyValueStore: failed to persist: \(error)")
            }
        }
    }

    private static func load(from url: URL, using fileSystemService: FileSystemService) -> [String: Double] {
        guard let data = try? fileSystemService.fileContent(at: url),
              let dict = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return [:]
        }
        return dict
    }
}

#endif // canImport(Synchronization)
