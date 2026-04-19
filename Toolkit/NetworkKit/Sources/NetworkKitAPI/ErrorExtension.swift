// ErrorExtension.swift

import Foundation

public extension Error {

    /// Should be used it avoid logging general errors, which we can't fix
    /// - returns: true is error is about timeout, bad internet connection, some ssl issue.
    var isGeneralNetworkError: Bool {
        return isNoInternetConnectionError || isTimeOurError || isInternetConnectionLostError
            || isSecureConnectionFailedError || isCannotConnectToHostError
            || isCannotFindHostError || isCancelled || isDataNotAllowed || isRoamingOff
    }

    var isNoInternetConnectionError: Bool {
        if let apiError = self as? ApiClientError {
            switch apiError {
            case .generalNetworkError: return true
            default: return false
            }
        }

        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorNotConnectedToInternet
    }

    var isTimeOurError: Bool {
        return nsError?.domain == NSURLErrorDomain && nsError?.code == NSURLErrorTimedOut
    }

    var isInternetConnectionLostError: Bool {
        return nsError?.domain == NSURLErrorDomain && nsError?.code == NSURLErrorNetworkConnectionLost
    }

    var isSecureConnectionFailedError: Bool {
        return nsError?.domain == NSURLErrorDomain && nsError?.code == NSURLErrorSecureConnectionFailed
    }

    var isCannotConnectToHostError: Bool {
        return nsError?.domain == NSURLErrorDomain && nsError?.code == NSURLErrorCannotConnectToHost
    }

    var isCannotFindHostError: Bool {
        return nsError?.domain == NSURLErrorDomain && nsError?.code == NSURLErrorCannotFindHost
    }

    var isCancelled: Bool {
        return nsError?.domain == NSURLErrorDomain && nsError?.code == NSURLErrorCancelled
    }

    var isDataNotAllowed: Bool {
        return nsError?.domain == NSURLErrorDomain && nsError?.code == NSURLErrorDataNotAllowed
    }

    var isRoamingOff: Bool {
        return nsError?.domain == NSURLErrorDomain && nsError?.code == NSURLErrorInternationalRoamingOff
    }

    private var nsError: NSError? {
        let nsError: NSError?
        if let apiError = self as? ApiClientError {
            switch apiError {
            case let .incorrectResponseType(error, _):
               nsError = error as NSError?

            default:
               return nil
            }
        } else {
            nsError = self as NSError
        }

        return nsError
    }
}
