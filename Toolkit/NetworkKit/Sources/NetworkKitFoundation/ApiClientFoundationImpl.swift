// ApiClientFoundationImpl.swift

import Foundation
import FoundationExtension
import NetworkKitAPI

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

public extension ApiClient {
    func request<ResponseType: ParsableFromUrlResponse>(_ request: URLRequest, progress: Progress? = nil) async throws(ApiClientError) -> ResponseType {
        let requestable = try RequestableURLRequest<ResponseType>(urlRequest: request)
        return try await self.request(requestable, progress: progress)
    }
}

public final class ApiClientFoundationImpl: ApiClient, Sendable {

    public init(platformHeadersProvider: PlatformHeadersProvider,
                configuration: URLSessionConfiguration = URLSessionConfiguration.ephemeral,
                logger: ApiClientLogger) {
        self.platformHeadersProvider = platformHeadersProvider
        self.logger = logger
        self.transport = URLSessionTransport(configuration: configuration)
    }

    public init(platformHeadersProvider: PlatformHeadersProvider,
                transport: NetworkTransport,
                logger: ApiClientLogger) {
        self.platformHeadersProvider = platformHeadersProvider
        self.logger = logger
        self.transport = transport
    }

    @discardableResult
    public func request<R: Requestable>(_ requestable: R, progress: Progress?) async throws(ApiClientError) -> R.ResponseType {
        do {
            return try await _request(requestable, progress: progress)
        } catch let apiClientError as ApiClientError {
            throw apiClientError
        } catch {
            logger.logWarning("Got non ApiClientError error, will wrap it to ApiClientError.generalNetworkError. error type - \(type(of: error as Any)). Error - \(error)")
            throw ApiClientError.generalNetworkError(error)
        }
    }

    // MARK: - Private

    private let platformHeadersProvider: PlatformHeadersProvider
    private let logger: ApiClientLogger
    private let transport: NetworkTransport

    // This method here because `withTaskCancellationHandler` and `withCheckedThrowingContinuation` don't have types throw
    // So I will try to re-type error from method with completion
    @discardableResult
    private func _request<R: Requestable>(_ requestable: R, progress: Progress?) async throws -> R.ResponseType {
        let cancelationWrapper = CancelationWrapper()

        return try await withTaskCancellationHandler(
            operation: {
                try await withCheckedThrowingContinuation { continuation in
                    var request = requestable.createRequest(logger: nil)
                    for (key, value) in self.platformHeadersProvider.platformHeaders where request.value(forHTTPHeaderField: key) == nil {
                        request.setValue(value, forHTTPHeaderField: key)
                    }
                    let task = self.request(request) { result in
                        continuation.resume(with: result)
                    }
                    cancelationWrapper.set(task)

                    if let progress {
                        progress.addChild(task.progress, withPendingUnitCount: progress.totalUnitCount)
                    }
                }
            },
            onCancel: {
                cancelationWrapper.cancel()
            }
        )
    }

    // I'm still using method with task and completion, because tracking progress otherwise is complicated and will require some testing on upload + download progress on usual data task
    private func request<ResponseType: ParsableFromUrlResponse>(_ request: URLRequest,
                                                                completion: @escaping @Sendable (ApiClientResult<ResponseType>) -> Void) -> ApiClientTask {
        let urlString = request.url?.absoluteString ?? "<REQUEST_DONT_HAVE_URL>"
        if logger.isDebugEnabled {
            let headersString = request.allHTTPHeaderFields?.map { "\($0): \($1)" }.joined(separator: "\n") ?? "nil"
            if let existedData = request.httpBody {
                let postBodyString = String(data: existedData, encoding: .utf8) ?? "<Unable to get textual presentation of post body. Size \(existedData.count)>"
                logger.logDebug(urlString + ". " + postBodyString + "\nHeaders\n" + headersString)
            } else {
                logger.logDebug(urlString + ". No post body in request.\nHeaders\n" + headersString)
            }
        }

        let task = transport.send(request) { [weak self, logger] (data: Data?, response: URLResponse?, error: Error?) in

            guard let self else {
                completion(.failure(.incorrectResponseType(CommonError.tooEarlyDeallocated(Self.self), nil)))
                return
            }

            logger.logDebug("Network task for URL \(urlString) finished: passing data to handle received information")

            let result: ApiClientResult<ResponseType> = self.handleResponse(on: request, data, response: response, error: error)
            completion(result)
        }

        return task
    }

    private func handleResponse<ResponseType: ParsableFromUrlResponse>(on request: URLRequest,
                                                                       _ data: Data?,
                                                                       response: URLResponse?,
                                                                       error: Error?) -> ApiClientResult<ResponseType> {
        guard let httpResponse: HTTPURLResponse = response as? HTTPURLResponse else {
            if error?.isGeneralNetworkError == true {
                logger.logWarning("Offline network error")
                return .failure(.generalNetworkError(error))
            }
            logger.logError("For some reason response nil or not HTTP response: \(String(describing: response)), while error is \(String(describing: error))")
            return .failure(.incorrectResponseType(error, response.map { String(describing: $0) }))
        }

        // Assume that if response type - NoResponseType, it will be ok to handle Data()
        let existedData = data ?? Data()

        if existedData.count > 0, let string = String(bytes: existedData, encoding: .utf8) {
            logger.logDebug("Textual representation of response body:\n" + string)
        } else {
            logger.logDebug("No textual representation of response body")
        }

        let validStatus = IndexSet(integersIn: 200...299)

        guard validStatus.contains(httpResponse.statusCode) else {
            let apiError = ApiClientError.badStatusCode(statusCode: httpResponse.statusCode,
                                                        data: data,
                                                        responseHeaders: httpResponse.allHeaders(),
                                                        request: request.requestInfo)
            logger.logApiError(apiError)
            return .failure(apiError)
        }

        logger.logDebug("Handling completion from URL: \(String(describing: request.url)), method: \(String(describing: request.httpMethod)) status code: \(httpResponse.statusCode)")

        let response: ResponseType
        do {
            let headers = httpResponse.allHeaders()
            response = try ResponseType.init(statusCode: httpResponse.statusCode,
                                             headers: headers,
                                             data: existedData)
        } catch {
            return .failure(.failedToParseResponseData(data, error, httpResponse.statusCode))
        }

        return .success(response)
    }
}

extension URLSessionTask: ApiClientTask {}

private final class CancelationWrapper: @unchecked Sendable {
    private let lock = PosixLock()
    private var isCancelled: Bool = false
    private var task: ApiClientTask?

    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        isCancelled = true
        task?.cancel()
        task = nil
    }

    func set(_ task: ApiClientTask) {
        lock.lock()
        defer { lock.unlock() }
        guard !isCancelled else {
            task.cancel()
            return
        }
        self.task = task
    }
}
