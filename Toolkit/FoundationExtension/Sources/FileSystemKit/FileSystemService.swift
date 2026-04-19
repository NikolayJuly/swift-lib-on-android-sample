// FileSystemService.swift

import CoreFoundation
import Foundation
import FoundationExtension

public protocol FileSystemService: AnyObject, Sendable {

    var libraryFolderUrl: URL { get }

    /// Check that folder at URL exists and it is folder, not a file
    func folderExists(at folderUrl: URL) -> Bool

    /// Check that file at URL exists and it is file, not a folder
    func fileExists(at fileUrl: URL) -> Bool

    /// Sync writing to file, take care about performance
    @available(*, noasync, message: "Use async version of this function")
    func write(data: Data, to url: URL) throws

    func write(data: Data, to url: URL) async throws

    /// - Throws: FileSystemServiceError
    @available(*, noasync, message: "Use async version of this function")
    func fileContent(at url: URL) throws -> Data

    /// If folder exists - it will be deleted and recreated.
    /// All parent folders in path must exists
    func createEmptyFolder(at folderUrl: URL) throws

    /// If folder exists - nothing happen. If not - will be created.
    /// All parent folders in path must exists.
    /// - throws: if no folder exist and failed to create
    func createFolderIfNotExists(at folderUrl: URL) throws

    func excludeFromBackup(_ url: URL) throws

    func removeItem(at URL: URL) throws

    func createSyncWriteFileStream(at fileUrl: URL) throws -> SyncWriteFileStream
}

public extension FileSystemService {

    /// Create all needed subfolders starts from `rootFolderUrl`. If any folder in chain existed, it will stay untouched
    /// - parameter fileUrl: should be desiredFile, since name last path component will be excluded from creation loop
    func createAllSubfolders(forFile fileUrl: URL, in rootFolderUrl: URL) throws {

        let desiredFolderUrl = fileUrl.normalized().deletingLastPathComponent()

        try createAllSubfolders(upTo: desiredFolderUrl, in: rootFolderUrl)
    }

    /// Create all needed subfolders starts from `rootFolderUrl`. If any folder in chain existed, it will stay untouched
    /// - parameter targetFolderUrl: should be desired folder, because in the end we will create folder with this name
    func createAllSubfolders(upTo targetFolderUrl: URL, in rootFolderUrl: URL) throws {

        try createFolderIfNotExists(at: rootFolderUrl)

        // we should create all subfolders
        let subPathComponents = try targetFolderUrl.pathComponents(relativeTo: rootFolderUrl)

        var currentFolderUrl = rootFolderUrl
        for pathComponent in subPathComponents {
            currentFolderUrl = currentFolderUrl.appendingPathComponent(pathComponent, isDirectory: true)
            try createFolderIfNotExists(at: currentFolderUrl)
        }
    }

    func write(data: Data, to url: URL) throws {
        let syncFileStream = try createSyncWriteFileStream(at: url)
        try syncFileStream.write(data)
    }

    func createFolderIfNotExists(at folderUrl: URL) throws {
        guard folderExists(at: folderUrl) == false else {
            return
        }

        try createEmptyFolder(at: folderUrl)
    }
}
