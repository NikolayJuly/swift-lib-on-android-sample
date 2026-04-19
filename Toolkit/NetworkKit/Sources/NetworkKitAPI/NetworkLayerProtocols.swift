// NetworkLayerProtocols.swift

import Foundation
import FoundationExtension


/// Describe every request - type of request/response as well as interfaces to pars them
public protocol Requestable: Sendable {

    associatedtype PostBodyType: DataPresentable

    associatedtype ResponseType: ParsableFromUrlResponse

    /// Endpoint URL
    var url: URL { get }

    var httpMethod: HttpMethod { get }

    var postBody: PostBodyType? { get }

    /// Request-specific headers (e.g. Authorization). Platform headers (device, app version)
    /// are added by `ApiClient` via `PlatformHeadersProvider`.
    var headers: [String: String]? { get }

}

public protocol RequestFactory: Sendable {
    associatedtype Request: Requestable

    func make() -> Request
}

/// API for object which present post body of request
public protocol DataPresentable {

    typealias DataPresentation = (data: Data?, format: String?)

    /// For http headers, for example, can return "application/json"
    var dataPresentation: DataPresentation? { get }
}

/// API for object which present response
public protocol ParsableFromUrlResponse: Sendable {

    /// Create object with data. Will be called on background thread so can be done long running functions
    init(statusCode: Int, headers: [String: String], data: Data) throws
}

// MARK: Header Names

public extension String {
    static let platformHeaderName = "Platform"
    static let bundleIdHeaderName = "BundleId"
    static let deviceIdHeaderName = "device"
    static let appVersionHeaderName = "AppVersion"
}

// MARK: Requestable Default Implementations

extension Requestable {

    public var headers: [String: String]? {
        nil
    }
}

/// MARK: Provide struct for cases when request don't have data types
public struct NoPostDataType: DataPresentable, Sendable {
    public var dataPresentation: DataPresentable.DataPresentation? {
        return nil
    }
}

extension Never: DataPresentable {
    public var dataPresentation: DataPresentation? {
        return nil
    }
}

extension String: DataPresentable {
    public var dataPresentation: DataPresentation? {
        let data = Data(self.utf8)
        return (data, "text/plain")
    }
}

/// MARK: Provide struct for cases when request don't have data types
public struct JSONDataType: DataPresentable, Sendable {

    private let data: Data

    public init(data: Data) {
        self.data = data
    }
    public var dataPresentation: DataPresentable.DataPresentation? {
        return (data, "application/json")
    }
}

// MARK: Provide class for cases when response don't have data types
public struct NoResponseType: ParsableFromUrlResponse, Sendable {
    public init(statusCode: Int, headers: [String: String], data: Data) { }
    public init() {}
}

extension Data: ParsableFromUrlResponse {
    public init(statusCode: Int, headers: [String: String], data: Data) {
        self = data
    }

    public init(data: Data) {
        self = data
    }
}
