// FileManager+FileSystemService.swift

import Foundation
import FoundationExtension

#if canImport(Android)
import Android
#endif

#if !canImport(FoundationExtension)
// Documentation says that ``FileManager`` is thread-safe in general, so mark as ``Sendable``
extension FileManager: @unchecked @retroactive Sendable {}
#endif

extension FileManager: FileSystemService {

#if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(Linux)
    @inlinable
    public var libraryFolderUrl: URL {
        let libraryUrls = urls(for: .libraryDirectory, in: .userDomainMask)
        let libraryUrl = libraryUrls[0]
        return libraryUrl
    }

#elseif os(Android)

    public var libraryFolderUrl: URL {
        Self.appPackageRoot.appending(path: "no_backup", directoryHint: .isDirectory)
    }

    private static let appPackageRoot: URL = {
        if Bool.isTesting {
            return URL(fileURLWithPath: "/data/local/tmp/tests")
        }
        return URL(fileURLWithPath: "/data/user/0/\(String.androidPackageId)")
    }()
#else
#error("Missing implementation of common app bundle folders for current plaform")
#endif

    public func folderExists(at folderUrl: URL) -> Bool {
        var isDir: ObjCBool = false
        let folderExists = fileExists(atPath: folderUrl.path, isDirectory: &isDir)

        return folderExists && isDir.boolValue
    }

    public func fileExists(at fileUrl: URL) -> Bool {
        var isDir: ObjCBool = false
        let exists = fileExists(atPath: fileUrl.path, isDirectory: &isDir)

        return exists && !isDir.boolValue
    }

    @available(*, noasync, message: "Use async version of this function")
    public func write(data: Data, to url: URL) throws {
        try data.write(to: url)
    }

    @concurrent
    public func write(data: Data, to url: URL) async throws {
        try await write(data: data, to: url, chunkSize: .defaultWriteChunkSize)
    }

    @concurrent
    func write(data: Data, to url: URL, chunkSize: Int) async throws {
        let fileStream = try AsyncFileStream<AsyncFileStreamWriteMode>(url: url)
        let dispatchData = data.withUnsafeBytes { DispatchData(bytes: $0) }
        try await fileStream.write(dispatchData, chunkSize: chunkSize)
    }

    @available(*, noasync, message: "Use async version of this function")
    public func fileContent(at url: URL) throws -> Data {
        guard let existedFileData = contents(atPath: url.path) else {
            throw FileSystemServiceError.fileDoesntExists(url)
        }

        return existedFileData
    }

    public func createFolderIfNotExists(at folderUrl: URL) throws {
        if folderExists(at: folderUrl) {
            return
        }
        if fileExists(atPath: folderUrl.path) {
            throw SimpleError("Trying to create folder, but a file already exists at path - \(folderUrl.absoluteURL)")
        }
        do {
            try createDirectory(at: folderUrl, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw SimpleError("Failed to create folder at \(folderUrl.absoluteURL): \(error)")
        }
    }

    public func createEmptyFolder(at folderUrl: URL) throws {
        try? removeItem(at: folderUrl)

        do {
            try createDirectory(at: folderUrl, withIntermediateDirectories: false, attributes: nil)
        } catch {
            throw SimpleError("Failed to create folder at \(folderUrl.absoluteURL): \(error)")
        }
    }

    public func excludeFromBackup(_ url: URL) throws {
        // This function really make sense only on Darwin systems and only in app store releases, not CLI
        #if os(iOS) || os(tvOS) || os(watchOS) || os(macOS)
            var mutableUrl = url
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try mutableUrl.setResourceValues(resourceValues)
        #endif // os(iOS) || os(tvOS) || os(watchOS) || os(macOS)
    }

    public func createSyncWriteFileStream(at fileUrl: URL) throws -> SyncWriteFileStream {
        try? removeItem(at: fileUrl)
        let created = createFile(atPath: fileUrl.path, contents: nil, attributes: nil)
        guard created else {
            throw FileSystemServiceError.unableToCreateWriteFileStream(fileUrl)
        }

        #if os(Android) || os(Linux)
            return try POSIXWriteFileStream(url: fileUrl)
        #else
            return try FileHandle(forWritingTo: fileUrl)
        #endif
    }
}

#if canImport(Android)

import Android

private extension String {
    // From ChatGPT
    static let androidPackageId: String = { () -> String in
        guard let f = fopen("/proc/self/cmdline", "r") else {
            fatalError("Unexpected failure to open /proc/self/cmdline")
        }

        defer { fclose(f) }
        var buf = [CChar](repeating: 0, count: 4096)
        let n = fread(&buf, 1, buf.count, f)

        guard n > 0 else {
            fatalError("Unexpected n == 0 from fread")
        }

        let s = buf.withUnsafeBufferPointer { ptr in
            String(validatingCString: ptr.baseAddress!)
        }
        guard var s = s else {
            fatalError("Failed to read string from /proc/self/cmdline")
        }

        if let i = s.firstIndex(of: ":") {    // strip :remote if present
            s = String(s[..<i])
        }
        precondition(s.isEmpty == false, "unexpected empty /proc/self/cmdline")
        return s
    }()
}

#endif
