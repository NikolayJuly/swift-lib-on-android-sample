#if canImport(Android)

import NetworkKitAPI

extension ApiClientError {
    /// Maps a Java/Android error to `ApiClientError` for request-level errors.
    /// On Android, Java exceptions are caught as Swift `Error` and their description
    /// contains the Java exception class name.
    static func fromAndroidError(_ error: Error) -> ApiClientError {
        let description = String(describing: error)

        if description.contains(/SocketTimeoutException/)
            || description.contains(/ConnectException/)
            || description.contains(/UnknownHostException/)
            || description.contains(/NoRouteToHostException/) {
            return .generalNetworkError(error)
        }

        return .incorrectResponseType(error, nil)
    }
}

#endif
