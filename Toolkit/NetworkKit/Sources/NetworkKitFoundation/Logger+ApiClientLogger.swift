// Logger+ApiClientLogger.swift

import Logging
import NetworkKitAPI

extension Logger: ApiClientLogger {

    public func logDebug(_ message: @autoclosure () -> String) {
        self.debug("\(message())")
    }

    public func logWarning(_ message: @autoclosure () -> String) {
        self.warning("\(message())")
    }

    public func logError(_ message: @autoclosure () -> String) {
        self.error("\(message())")
    }

    public func logApiError(_ error: ApiClientError) {
        switch error {
        case let .badStatusCode(statusCode, data, responseHeaders, request):
            let postBody = request.body.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
            let responseBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
            let headersString = responseHeaders.map { "\($0.key): \($0.value)" }
            let message = """
                Wrong status code: \(statusCode)
                    urlTask.currentRequest?.URL = \(request.url ?? "nil")
                    method: \(request.httpMethod ?? "nil")
                    PostBody:
                        \(postBody)
                    ResponseHeaders: \(headersString)
                    ResponseBody:
                        \(responseBody)
                """
            self.error("\(message)")
        default:
            self.error("\(error)")
        }
    }

    public var isDebugEnabled: Bool {
        logLevel == .debug
    }
}
