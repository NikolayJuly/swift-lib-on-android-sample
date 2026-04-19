// URLExtension.swift

import Foundation

extension URL {
    /// resolve symlinks, make absolute
    @inlinable
    public func normalized() -> URL {
        let absolute: URL
        if let baseURLUnwrapped = baseURL {
            // assume here that relative path will be ONLY to dir
            let copyBaseUrl = URL(fileURLWithPath: baseURLUnwrapped.path, isDirectory: true)
            let copyUrl = URL(string: relativeString, relativeTo: copyBaseUrl)!
            absolute = copyUrl
        } else {
            absolute = self
        }

        return absolute.absoluteURL.resolvingSymlinksInPath()
    }

    /// Calculate relative path of self to `relativeTo`
    /// - parameter relativeTo: base url for calculation
    /// - throws: Throw exception if `relativeTo` is not part of self
    @inlinable
    public func pathComponents(relativeTo rootUrl: URL) throws -> [String] {
        let normalizedSelf = self.normalized()
        let normalizedRoot = rootUrl.normalized()

        let rootFolderComponents =  normalizedRoot.pathComponents
        var components = normalizedSelf.pathComponents

        let componentsPrefix = components.prefix(rootFolderComponents.count)
        guard componentsPrefix.elementsEqual(rootFolderComponents) else {
            throw FileSystemServiceError.rootUrlDoNotContainDesired(rootUrl: rootUrl, desired: self)
        }

        components.removeFirst(rootFolderComponents.count)
        return components
    }

    @inlinable
    public func appendingPathComponents(_ components: some BidirectionalCollection<String>, isDirectory: Bool) -> URL {

        guard let last = components.last else {
            return self
        }

        let slice = components.dropLast()
        let containingFolderUrl = slice.reduce(self) { (currentUrl, folderName) in
            return currentUrl.appendingPathComponent(folderName, isDirectory: true)
        }

        return containingFolderUrl.appendingPathComponent(last, isDirectory: isDirectory)
    }
}
