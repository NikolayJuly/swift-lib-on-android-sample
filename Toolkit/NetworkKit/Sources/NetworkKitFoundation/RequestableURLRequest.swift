// RequestableURLRequest.swift

import Foundation
import FoundationExtension
import Logging
import NetworkKitAPI

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct URLRequestPostData: DataPresentable {
    let data: Data?
    let contentType: String?

    var dataPresentation: DataPresentation? { (data, contentType) }
}

struct RequestableURLRequest<RT: ParsableFromUrlResponse>: Requestable {

    typealias PostBodyType = URLRequestPostData

    typealias ResponseType = RT

    let urlRequest: URLRequest

    let url: URL
    let httpMethod: HttpMethod

    let postBody: PostBodyType?

    var headers: [String: String]? {
        urlRequest.allHTTPHeaderFields
    }

    init(urlRequest: URLRequest) throws(ApiClientError) {
        self.url = try urlRequest.url.unwrapped(otherwise: ApiClientError.invalidUrl)
        self.httpMethod = try urlRequest.httpMethod
                                        .flatMap { HttpMethod(rawValue: $0) }
                                        .unwrapped(otherwise: ApiClientError.invalidHttpMethod(urlRequest.httpMethod))
        self.postBody = URLRequestPostData(data: urlRequest.httpBody,
                                           contentType: urlRequest.allHTTPHeaderFields?["Content-Type"])
        self.urlRequest = urlRequest
    }
}

private extension ApiClientError {
    static let invalidUrl: ApiClientError = ApiClientError.invalidRequest(SimpleError("URL is missing"))
    static func invalidHttpMethod(_ value: String?) -> ApiClientError {
        ApiClientError.invalidRequest(SimpleError("Invalid HTTP method: \(value ?? "nil")"))
    }
}
