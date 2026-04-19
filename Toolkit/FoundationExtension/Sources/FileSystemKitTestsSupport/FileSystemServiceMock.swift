// FileSystemServiceMock.swift

import FileSystemKit
import Foundation
import FoundationExtension

infix operator ==~: ComparisonPrecedence

public enum FileSystemMockError: LocalizedError, CustomStringConvertible, CustomNSError {
    case parentFolderDoesntExist(URL)
    case fileDoesntExist(URL)
    case folderDoesntExist(URL)
    case mismatchedEntityTypes(URL, isDir: Bool)
    case entityAlreadyExists(URL)

    public var description: String {
        switch self {
        case let .parentFolderDoesntExist(url): "FileSystemMockError.parentFolderDoesntExist(\(url.path))"
        case let .fileDoesntExist(url): "FileSystemMockError.fileDoesntExist(\(url.path))"
        case let .folderDoesntExist(url): "FileSystemMockError.folderDoesntExist(\(url.path))"
        case let .mismatchedEntityTypes(url, isDir): "FileSystemMockError.mismatchedEntityTypes(\(url.path), \(isDir))"
        case let .entityAlreadyExists(url): "FileSystemMockError.entityAlreadyExists(\(url.path))"
        }
    }

    public var errorDescription: String? {
        return description
    }

    public static let errorDomain: String = "FileSystemMockErrorDomain"

    public var errorCode: Int {
        switch self {
        case .parentFolderDoesntExist: 1
        case .fileDoesntExist: 2
        case .folderDoesntExist: 3
        case .mismatchedEntityTypes: 4
        case .entityAlreadyExists: 5
        }
    }

    public var errorUserInfo: [String : Any] {
        return [NSLocalizedDescriptionKey: description]
    }
}

// `@unchecked Sendable` — thread safety is provided by NSRecursiveLock
public final class FileSystemServiceMock: FileSystemService, FileSystemFolder,
                                          CustomStringConvertible, CustomDebugStringConvertible, @unchecked Sendable {

    public let rootUrl: URL
    public var rootContent = [FileSystemEntity]()

    private let lock = NSRecursiveLock()

    public var content: [FileSystemEntity] {
        rootContent
    }

    public var libraryFolderUrl: URL {
        rootUrl.appendingPathComponent("Libraries", isDirectory: true)
    }

    public init(rootUrl: URL, content: [FileSystemEntity]) {
        self.rootUrl = rootUrl.normalized()
        self.rootContent = content
        for entity in content {
            guard let entityParent = entity.parent as? FileSystemServiceMock else {
                assert(false)
                continue
            }
            assert(entityParent === self)
        }

        try! createFolderIfNotExists(at: libraryFolderUrl)
    }

    // MARK: FileSystemService

    public func folderExists(at folderUrl: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let folderOrNil = findEntity(at: folderUrl)
        return folderOrNil?.isDirectory == true
    }

    public func fileExists(at fileUrl: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return findEntity(at: fileUrl)?.isDirectory == false
    }

    public func write(data: Data, to url: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        let parentFolderUrl = url.deletingLastPathComponent()
        guard let existedFolder = findFolder(at: parentFolderUrl) else {
             throw FileSystemMockError.folderDoesntExist(parentFolderUrl)
        }

        let filename = url.lastPathComponent
        let existingItem = existedFolder.content.first(where: { $0.name == filename })

        if let existingItem, !existingItem.isDirectory {
            existingItem.data = data
        } else if let existingItem {
            throw FileSystemMockError.entityAlreadyExists(existingItem.url)
        } else {
            let file = FileSystemEntity(fileName: filename, data: data)
            try existedFolder.add(file)
        }
    }

    public func createSyncWriteFileStream(at fileUrl: URL) throws -> SyncWriteFileStream {
        lock.lock()
        defer { lock.unlock() }
        let parentFolderUrl = fileUrl.deletingLastPathComponent()

        if let existedFile = findEntity(at: fileUrl) {
            guard !existedFile.isDirectory else {
                throw FileSystemMockError.mismatchedEntityTypes(fileUrl, isDir: true)
            }

            let parentFolder = existedFile.parent
            try parentFolder?.remove(named: fileUrl.lastPathComponent)
        }

        guard let folder = findFolder(at: parentFolderUrl) else {
            throw FileSystemMockError.parentFolderDoesntExist(parentFolderUrl)
        }

        let newFile = FileSystemEntity(fileName: fileUrl.lastPathComponent, data: Data())
        try folder.add(newFile)

        return newFile
    }

    public var fileContentHistory: [URL] = []

    public func fileContent(at url: URL) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        fileContentHistory.append(url)
        guard let file = findEntity(at: url), !file.isDirectory else {
            throw FileSystemMockError.fileDoesntExist(url)
        }

        return file.data
    }

    public func createEmptyFolder(at folderUrl: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        let parentFolderUrl = folderUrl.deletingLastPathComponent()
        guard let parentFolder = findFolder(at: parentFolderUrl) else {
            throw FileSystemMockError.parentFolderDoesntExist(folderUrl)
        }

        let folderName = folderUrl.normalized().lastPathComponent
        try? parentFolder.remove(named: folderName)

        let newFolder = FileSystemEntity(folderName: folderName)
        try parentFolder.add(newFolder)
    }

    public func createFolderIfNotExists(at folderUrl: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        if folderUrl.normalized() ==~ rootUrl {
            // we assume root folder always exists
            return
        }

        let parentFolderUrl = folderUrl.deletingLastPathComponent()
        guard let parentFolder = findFolder(at: parentFolderUrl) else {
            throw FileSystemMockError.parentFolderDoesntExist(folderUrl)
        }

        guard !folderExists(at: folderUrl) else {
            return
        }

        let folderName = folderUrl.normalized().lastPathComponent

        let newFolder = FileSystemEntity(folderName: folderName)
        try parentFolder.add(newFolder)
    }

    public func excludeFromBackup(_ url: URL) { }

    public func removeItem(at URL: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        guard let entity = findEntity(at: URL) else {
            throw FileSystemMockError.fileDoesntExist(URL)
        }

        try entity.parent?.remove(named: entity.name)
    }

    // MARK: FileSystemFolder

    public var url: URL {
        return rootUrl
    }

    public func add(_ entity: FileSystemEntity) throws {
        lock.lock()
        defer { lock.unlock() }
        if let _ = rootContent.first(where: { $0.name == entity.name }) {
            throw FileSystemMockError.entityAlreadyExists(entity.url)
        }

        rootContent.append(entity)
        entity.parent = self
    }

    public func remove(named name: String) throws {
        lock.lock()
        defer { lock.unlock() }
        guard let index = rootContent.firstIndex(where: { $0.name == name }) else {
            throw FileSystemMockError.fileDoesntExist(rootUrl.appendingPathComponent(name))
        }
        rootContent[index].parent = nil
        rootContent.remove(at: index)
    }

    public func findFolder(at folderUrl: URL) -> FileSystemFolder? {
        lock.lock()
        defer { lock.unlock() }
        if folderUrl.normalized() ==~ rootUrl {
            return self
        }

        let allElements = rootContent.flatMap({ $0.flatSubEntitiesTree() })
        let normalizedFolderUrl = folderUrl.normalized()
        let element = allElements.first(where: { $0.url.normalized() ==~ normalizedFolderUrl })

        if element?.isDirectory != true {
            return nil
        }

        return element
    }

    public func findEntity(at desiredUrl: URL) -> FileSystemEntity? {
        lock.lock()
        defer { lock.unlock() }
        let allElements = rootContent.flatMap({ $0.flatSubEntitiesTree() })
        let normalizedDesired = desiredUrl.normalized()
        return allElements.first(where: { $0.url.normalized() ==~ normalizedDesired })
    }

    // MARK: CustomStringConvertible

    public var description: String {
        lock.lock()
        defer { lock.unlock() }
        return "FileSystemServiceMock:\n\(rootUrl.path)\n" + printContent(prefix: "").joined(separator: "\n")
    }

    // MARK: CustomDebugStringConvertible

    public var debugDescription: String {
        lock.lock()
        defer { lock.unlock() }
        return "FileSystemServiceMock:\n\(rootUrl.path)\n" + printContent(prefix: "").joined(separator: "\n")
    }
}

private extension FileSystemFolder {
    func printContent(prefix: String) -> [String] {
        let (folders, files) = content.separate(predicate: { $0.isDirectory })
        let foldersContent: [String] = folders.sorted(by: { $0.name < $1.name }).flatMap {
            let folderString = prefix + "|-- " + $0.name + "/"
            let folderContent = $0.printContent(prefix: prefix + "|   ")
            return [folderString] + folderContent
        }

        let filesContent: [String] = files.sorted(by: { $0.name < $1.name }).map {
            prefix + "|-- " + $0.name
        }
        return foldersContent + filesContent
    }
}

private extension URL {
    // Ignore last '/', otherwise it cause many problems. We assume that there can't be folder and file with the same name at the same URL
    static func ==~ (lhs: URL, rhs: URL) -> Bool {
        let lhsS = lhs._string()
        let rhsS = rhs._string()
        return lhsS == rhsS
    }

    private func _string() -> String {
        let string = self.normalized().absoluteString
        if string.last == "/" {
            return string
        }
        return string + "/"
    }
}
