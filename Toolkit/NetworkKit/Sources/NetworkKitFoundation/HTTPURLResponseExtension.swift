// HTTPURLResponseExtension.swift

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension HTTPURLResponse {
    func allHeaders() -> [String: String] {
        let stringsTuples = allHeaderFields.map { ($0 as? String, $1 as? String) }
            .compactMap { $0.0 != nil && $0.1 != nil ? ($0.0!, $0.1!) : nil }
        return .init(uniqueKeysWithValues: stringsTuples)
    }

    /// Looks like SDK for linux(most likely any OSS SDK) don't have `init()` on `HTTPURLResponse`, but it works fine with SDK from Xcode
    /// - note: use only in tests.
    static func dummy() -> HTTPURLResponse {
        assert(.isTesting)
        return HTTPURLResponse(url: URL(string: "https://HTTPURLResponseExtension.com")!,
                               statusCode: 999,
                               httpVersion: "HTTP/1.1",
                               headerFields: [:])!
    }
}
