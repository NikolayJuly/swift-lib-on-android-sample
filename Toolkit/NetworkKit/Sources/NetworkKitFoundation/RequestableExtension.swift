// RequestableExtension.swift

import FoundationExtension
import Logging
import NetworkKitAPI

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

extension Requestable {
    public func createRequest(logger: Logger?) -> URLRequest {

        logger?.debug("Start creating request from \(type(of: self)) URL: \(self.url). Method: \(self.httpMethod.rawValue)")

        var request: URLRequest = URLRequest(url: self.url,
                                             cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData,
                                             timeoutInterval: 60)

        request.httpMethod = self.httpMethod.rawValue

        var allHTTPHeaderFields = self.headers ?? [String: String]()

        if let existedPost = self.postBody, let dataPresentation = existedPost.dataPresentation {
            request.httpBody = dataPresentation.data
            allHTTPHeaderFields["Content-Type"] = dataPresentation.format
        }

        for header in allHTTPHeaderFields {
            request.setValue(header.value, forHTTPHeaderField: header.key)
        }

        let headersText = request.allHTTPHeaderFields?.map { "\($0.key): \($0.value)" }.joined(separator: "\n") ?? ""
        logger?.debug("\(type(of: self)) Headers:\n\(headersText)")

        return request
    }
}
