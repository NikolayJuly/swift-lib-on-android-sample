// InMemoryFileSystemService.swift

import Foundation
import FoundationExtension

/// Thread safety is provided by NSRecursiveLock on all public methods
public final class InMemoryFileSystemService: FileSystemService {

    /// - parameter rootUrl: url of root in memory folder of FS
    /// - parameter appRootContainer: Root folder which contains `Documents`,  `Library` etc
    public init(rootUrl: URL,
                appRootContainer: URL) {
        self.rootUrl = rootUrl.normalized()
        self.rootFolder = FSItem(name: rootUrl.lastPathComponent, type: .folder)
        self.appRootContainer = appRootContainer
    }

    private let lock = NSRecursiveLock()

    public var libraryFolderUrl: URL { appRootContainer.appendingPathComponent("Library", isDirectory: true) }

    public func folderExists(at folderUrl: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let item = item(at: folderUrl)
        guard let item else {
            return false
        }
        return item.type == .folder
    }

    public func fileExists(at fileUrl: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let item = item(at: fileUrl)
        guard let item else {
            return false
        }
        return item.type == .file
    }

    public func createSyncWriteFileStream(at fileUrl: URL) throws -> SyncWriteFileStream {
        lock.lock()
        defer { lock.unlock() }
        let parentFolderUrl = fileUrl.deletingLastPathComponent()
        let parentFolder = item(at: parentFolderUrl)
        guard let parentFolder, parentFolder.type == .folder else {
            throw SimpleError("Folder at \(parentFolderUrl.absoluteString) doesn't exist")
        }

        let filename = fileUrl.lastPathComponent
        let newFile = FSItem(name: filename, type: .file)
        parentFolder.$content.mutate { content in
            content[filename] = newFile
        }
        return InMemoryWriteFileStream(fsItem: newFile)
    }

    public func fileContent(at url: URL) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        let item = item(at: url)
        guard let item, item.type == .file else {
            throw SimpleError("File doesn't exist - \(url.absoluteString)")
        }
        return item.data
    }

    public func createEmptyFolder(at folderUrl: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        let parentFolderUrl = folderUrl.deletingLastPathComponent()

        let parentFolder = item(at: parentFolderUrl)
        guard let parentFolder, parentFolder.type == .folder else {
            throw SimpleError("Folder doesn't exists at \(parentFolderUrl.absoluteString)")
        }

        let folderName = folderUrl.lastPathComponent

        let fsItem = FSItem(name: folderName, type: .folder)
        parentFolder.$content.mutate { content in
            content[folderName] = fsItem
        }
    }

    public func excludeFromBackup(_ url: URL) throws {}

    public func removeItem(at url: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        let parentUrl = url.deletingLastPathComponent()
        let parentItem = item(at: parentUrl)
        guard let parentItem, parentItem.type == .folder else {
            throw SimpleError("Parent folder doesn't exist at \(parentUrl.absoluteString)")
        }

        let name = url.lastPathComponent
        guard parentItem.content[name] != nil else {
            throw SimpleError("Item doesn't exist at \(url.absoluteString)")
        }

        parentItem.$content.mutate { content in
            content.removeValue(forKey: name)
        }
    }

    // MARK: Private

    private let rootUrl: URL
    private let appRootContainer: URL

    private let rootFolder: FSItem

    private func item(at url: URL) -> FSItem? {
        let components: [String]
        do {
            components = try url.pathComponents(relativeTo: rootUrl)
        } catch {
            return nil
        }

        guard let lastItemName = components.last else {
            return rootFolder
        }

        let subFolders = components.dropLast()

        var currentItem: FSItem = rootFolder
        for component in subFolders {
            guard let folder = currentItem.content[component], folder.type == .folder else {
                return nil
            }

            currentItem = folder
        }

        return currentItem.content[lastItemName]
    }
}

private final class FSItem: @unchecked Sendable {

    enum `Type` {
        case folder
        case file
    }

    let name: String

    let type: `Type`

    @Atomic
    var content: [String: FSItem] // Key is file/folder name

    @Atomic
    var data: Data

    init(name: String, type: `Type`) {
        self.name = name
        self.type = type
        self.data = Data()
        self.content = [:]
    }
}

private final class InMemoryWriteFileStream: SyncWriteFileStream {
    init(fsItem: FSItem) {
        self.fsItem = fsItem
    }

    func write(_ data: some DataProtocol) throws {
        fsItem.$data.mutate { inoutData in
            inoutData.append(contentsOf: data)
        }
    }

    func close() throws {}

    // MARK: Private

    private let fsItem: FSItem
}
