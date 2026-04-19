// ApiClient.swift

import Foundation

public enum HttpMethod: String, Sendable {
    case get = "GET"
    case head = "HEAD"
    case post = "POST"
    case put = "PUT"
}

public protocol ApiClientTask: Sendable {

    var progress: Progress { get }

    var taskIdentifier: Int { get }
    func cancel()
}

public typealias ApiClientResult<R: ParsableFromUrlResponse> = Result<R, ApiClientError>

public protocol ApiClient: Sendable {

    @discardableResult
    func request<R: Requestable>(_ requestable: R, progress: Progress?) async throws(ApiClientError) -> R.ResponseType
}

public extension ApiClient {
    func request<R: Requestable>(_ requestable: R) async throws -> R.ResponseType {
        try await request(requestable, progress: nil)
    }
}
