// ApiClientError.swift

import FoundationExtension

public struct RequestInfo: Sendable {
    public let url: String?
    public let httpMethod: String?
    public let headers: [String: String]?
    public let body: Data?

    public init(url: String?,
                httpMethod: String?,
                headers: [String: String]?,
                body: Data?) {
        self.url = url
        self.httpMethod = httpMethod
        self.headers = headers
        self.body = body
    }

    public init<R: Requestable>(_ requestable: R) {
        self.url = requestable.url.absoluteString
        self.httpMethod = requestable.httpMethod.rawValue
        self.headers = requestable.headers
        self.body = requestable.postBody?.dataPresentation?.data
    }
}

public enum ApiClientError: Error, EnumError, Sendable {
    case invalidRequest(Error)
    case incorrectResponseType(Error?, String?)
    case badStatusCode(statusCode: Int, data: Data?, responseHeaders: [String: String], request: RequestInfo)
    case failedToParseResponseData(Data?, Error, Int)
    case generalNetworkError(Error?)

    // MARK: CustomNSError

    public var errorCode: Int {
        switch self {
        case .invalidRequest: 0
        case .incorrectResponseType: 1
        case let .badStatusCode(statusCode, _, _, _): statusCode
        case .failedToParseResponseData: 2
        case .generalNetworkError: 3
        }
    }

    // MARK: LocalizedError

    public var description: String {
        switch self {
        case let .invalidRequest(error):
            return "We got invalid request. Error: \(error). (ApiClientError.invalidRequest)"
        case let .incorrectResponseType(error, responseDescription):
            let errorDesc: String
            if let errorUnwrapped = error {
                errorDesc = "\(errorUnwrapped)"
            } else {
                errorDesc = "nil"
            }
            return "We got incorrect response. Error: \(errorDesc), Response: \(responseDescription ?? "nil"). (ApiClientError.incorrectResponseType)"
        case let .badStatusCode(statusCode, responseData, _, request):
            let errorHint: String
            if let responseData, !responseData.isEmpty {
                errorHint = String(bytes: responseData, encoding: .utf8) ?? "We got \(responseData.count) bytes, but failed to get utf8 representation"
            } else {
                errorHint = "We didn't get any additional response data for debug"
            }

            let headersString: String
            if let headers = request.headers {
                headersString = headers.map { $0.key + ": " + $0.value }.joined(separator: "\n")
            } else {
                headersString = "nil"
            }
            let requestString = "\(request.httpMethod ?? "nil") \(request.url ?? "nil url")\n"
                                + "Headers:\n" + headersString

            return "Bad http status code - \(statusCode). Response contains \(responseData?.count ?? 0) bytes (ApiClientError.badStatusCode).\nErrorHint:\n \(errorHint)\nRequest:\n\(requestString)"
        case let .failedToParseResponseData(responseData, parsingError, statusCode):
            let errorHint: String
            if let responseData, !responseData.isEmpty {
                errorHint = String(bytes: responseData, encoding: .utf8) ?? "We got \(responseData.count) bytes, but failed to get utf8 representation"
            } else {
                errorHint = "We didn't get any additional response data for debug"
            }

            return "Failed to parse response. \(responseData?.count ?? 0) bytes with status code \(statusCode). Error - \(parsingError)\n ErrorHint:\n\(errorHint)\n(ApiClientError.failedToParseResponseData)"

        case let .generalNetworkError(error):
            return "General Network Error - \(error, default: "nil") (ApiClientError.generalNetworkError)"
        }
    }

    // MARK: EnumError

    public static let typeDescription: String = "ApiClientError"
}
