// FileSystemServiceError.swift

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum FileSystemServiceError: LocalizedError {

    case fileDoesntExists(URL)
    case unableToCreateWriteFileStream(URL)
    case rootUrlDoNotContainDesired(rootUrl: URL, desired: URL)

    // MARK: CustomNSError

    public static let errorDomain: String = "FileSystemServiceError"

    public var errorCode: Int {
        switch self {
        case .fileDoesntExists: 1
        case .unableToCreateWriteFileStream: 2
        case .rootUrlDoNotContainDesired: 3
        }
    }

    // MARK: LocalizedError

    public var description: String {
        switch self {
        case .fileDoesntExists(let fileUrl):
            return "File at \(fileUrl.path) can't be found (FileSystemServiceError.fileDoesntExists)"

        case .unableToCreateWriteFileStream(let fileUrl):
            return "Can't create writing stream at \(fileUrl.path) (FileSystemServiceError.unableToCreateWriteFileStream)"

        case .rootUrlDoNotContainDesired(let rootUrl, let desired):
            return "Root path is not part of desired one. Root: \"(\(rootUrl.path)\", desired: \"\(desired.path)\" (FileSystemServiceError.rootUrlDoNotContainDesired)"
        }
    }
}

#if !canImport(FoundationEssentials)
// If we see `FoundationEssentials` it means, we are in oss toolchain. Lets avoid full Foundation dependency
extension FileSystemServiceError: CustomNSError {}
#endif // !canImport(FoundationEssentials)
