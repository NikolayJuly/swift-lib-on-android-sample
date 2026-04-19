// NetworkTransport.swift

import Foundation
import NetworkKitAPI

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Abstraction over URLSession's data task mechanism.
/// Allows injecting test doubles without URLProtocol hacks.
public protocol NetworkTransport: Sendable {
    func send(_ request: URLRequest,
              completion: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> ApiClientTask
}

/// Default transport that delegates to a real URLSession.
public final class URLSessionTransport: NetworkTransport, Sendable {

    public let urlSession: URLSession

    public init(urlSession: URLSession) {
        self.urlSession = urlSession
    }

    public init(configuration: URLSessionConfiguration) {
        self.urlSession = URLSession(configuration: configuration)
    }

    public func send(_ request: URLRequest,
                     completion: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> ApiClientTask {
        let task = urlSession.dataTask(with: request, completionHandler: completion)
        task.resume()
        return task
    }
}
