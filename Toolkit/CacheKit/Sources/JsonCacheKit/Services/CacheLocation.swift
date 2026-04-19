// CacheLocation.swift

import FileSystemKit
import Foundation

public struct CacheLocation: Sendable {
    /// Might be folder or file, depending on usage
    public let cacheUrl: URL
    public let appContainerFolderUrl: URL

    public init(cacheUrl: URL, appContainerFolderUrl: URL) {
        self.cacheUrl = cacheUrl
        self.appContainerFolderUrl = appContainerFolderUrl
    }
}

public extension CacheLocation {
    /// - name: file name without extension, we will add `.json` here
    static func create(for fileName: String,
                       using fileSystemService: FileSystemService = FileManager.default) -> CacheLocation {
        let libraryFolderUrl = fileSystemService.libraryFolderUrl
        let fileUrl = libraryFolderUrl.appendingPathComponents(["RepositoriesCache", fileName + ".json"], isDirectory: false)
        return .init(cacheUrl: fileUrl, appContainerFolderUrl: libraryFolderUrl)
    }
}
