// ApiClientLogger.swift

import NetworkKitAPI

/// Abstracts all logging for ApiClient.
/// Default: `Logger` conforms via extension — logs everything at standard levels.
/// Custom: override `logApiError` to filter specific errors (e.g. expected 404s).
/// Method names prefixed with `log` to avoid collision with Logger's own methods,
/// which would cause wrong source file/line in log output.
public protocol ApiClientLogger: Sendable {
    func logDebug(_ message: @autoclosure () -> String)
    func logWarning(_ message: @autoclosure () -> String)
    func logError(_ message: @autoclosure () -> String)
    func logApiError(_ error: ApiClientError)

    var isDebugEnabled: Bool { get }
}
