// FileSystemEntity.swift

import FileSystemKit
import Foundation

public protocol FileSystemFolder: AnyObject {

    var url: URL { get }

    var content: [FileSystemEntity] { get }

    func add(_ entity: FileSystemEntity) throws

    func remove(named name: String) throws
}

// `@unchecked Sendable` here is a lie, but it is much simpler to ignore, because this for tests only
public final class FileSystemEntity: FileSystemFolder, SyncWriteFileStream, @unchecked Sendable {

    public let name: String
    public weak var parent: FileSystemFolder?

    public let isDirectory: Bool

    public var data: Data = Data()
    public var content = [FileSystemEntity]()

    /// Create file
    public init(fileName: String, data: Data) {

        self.name = fileName

        self.isDirectory = false

        self.data = data
    }

    /// Create folder
    public init(folderName: String) {

        self.name = folderName

        self.isDirectory = true
    }

    /// If file, return itself, if folder return itself and result of flat for all sub entities
    public func flatSubEntitiesTree() -> [FileSystemEntity] {
        guard isDirectory else {
            return [self]
        }

        return content.flatMap( { $0.flatSubEntitiesTree() }) + [self]
    }

    // MARK: FileSystemFolder

    public var url: URL {
        guard let parentUnwrapped = parent else {
            assert(false, "We can't request url of entity which removed from files tree")
        }
        return parentUnwrapped.url.appendingPathComponent(name, isDirectory: isDirectory)
    }

    public func add(_ entity: FileSystemEntity) throws {
        assert(isDirectory)

        if let foundIndex = content.firstIndex(where: { $0.name == entity.name }) {
            throw FileSystemMockError.entityAlreadyExists(content[foundIndex].url)
        }

        content.append(entity)
        entity.parent = self
    }

    public func remove(named name: String) throws {
        assert(isDirectory)

        guard let index = content.firstIndex(where: { $0.name == name }) else {
            let fileUrl = url.appendingPathComponent(name)
            throw FileSystemMockError.fileDoesntExist(fileUrl)
        }

        content[index].parent = nil
        content.remove(at: index)
    }

    // MARK: SyncWriteFileStream

    public func write(_ data: some DataProtocol) throws {
        self.data.append(contentsOf: data)
    }

    public func close() throws {}
}
