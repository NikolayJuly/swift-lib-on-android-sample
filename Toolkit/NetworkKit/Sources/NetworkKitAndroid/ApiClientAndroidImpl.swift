#if canImport(Android)

import CSwiftJavaJNI
import Foundation
import FoundationExtension
import JavaIO
import JavaNet
import Logging
import NetworkKitAPI
import SwiftJava

/// Typealias to disambiguate from `Foundation.URL`
private typealias JavaURL = JavaNet.URL
private typealias JavaInputStream = JavaIO.InputStream

public final class ApiClientAndroidImpl: ApiClient, Sendable {

    public init(platformHeadersProvider: PlatformHeadersProvider,
                connectTimeoutMs: Int32 = 25_000,
                readTimeoutMs: Int32 = 25_000,
                logger: Logger) {
        self.platformHeadersProvider = platformHeadersProvider
        self.logger = logger
        self.connectTimeoutMs = connectTimeoutMs
        self.readTimeoutMs = readTimeoutMs
    }

    @discardableResult
    public func request<R: Requestable>(_ requestable: R, progress: Progress?) async throws(ApiClientError) -> R.ResponseType {
        do {
            return try performRequest(requestable, progress: progress)
        } catch let error as ApiClientError {
            throw error
        } catch {
            logger.warning("Got non-ApiClientError: \(type(of: error)) - \(error)")
            throw .fromAndroidError(error)
        }
    }

    // MARK: - Private

    private let platformHeadersProvider: PlatformHeadersProvider
    private let logger: Logger
    private let connectTimeoutMs: Int32
    private let readTimeoutMs: Int32

    private func performRequest<R: Requestable>(_ requestable: R, progress: Progress?) throws -> R.ResponseType {
        let urlString = requestable.url.absoluteString

        logger.info("Start request \(requestable.httpMethod.rawValue) \(urlString)")

        // 1. Create java.net.URL and open connection
        let javaUrl = try JavaURL(urlString)
        guard let urlConnection = try javaUrl.openConnection() else {
            throw ApiClientError.invalidRequest(SimpleError("openConnection() returned nil"))
        }

        guard let connection = urlConnection.as(HttpURLConnection.self) else {
            throw ApiClientError.invalidRequest(SimpleError("Connection is not HttpURLConnection"))
        }

        // 2. Configure connection
        connection.setRequestMethod(requestable.httpMethod.rawValue)
        urlConnection.setConnectTimeout(connectTimeoutMs)
        urlConnection.setReadTimeout(readTimeoutMs)
        connection.setInstanceFollowRedirects(true)

        // 3. Set platform headers first, then request-specific headers (which can override)
        for (key, value) in platformHeadersProvider.platformHeaders {
            urlConnection.setRequestProperty(key, value)
        }
        if let headers = requestable.headers {
            for (key, value) in headers {
                urlConnection.setRequestProperty(key, value)
            }
        }

        // 4. Write post body if present
        if let postBody = requestable.postBody,
           let presentation = postBody.dataPresentation,
           let data = presentation.data {
            urlConnection.setDoOutput(true)

            if let contentType = presentation.format {
                urlConnection.setRequestProperty("Content-Type", contentType)
            }

            if let outputStream = try urlConnection.getOutputStream() {
                let bytes = [Int8](unsafeBitCast(Array(data), to: [Int8].self))
                try outputStream.write(bytes)
                try outputStream.flush()
                try outputStream.close()
            }
        }

        // 5. Get response
        let statusCode: Int
        do {
            statusCode = Int(try connection.getResponseCode())
        } catch {
            throw ApiClientError.fromAndroidError(error)
        }

        // 6. Read response data
        let responseData: Data
        do {
            let inputStream: JavaInputStream?
            if statusCode >= 400 {
                inputStream = connection.getErrorStream()
            } else {
                inputStream = try urlConnection.getInputStream()
            }

            if let stream = inputStream {
                let bytes = try stream.readAllBytesCompatible()
                responseData = Data(bytes.map { UInt8(bitPattern: $0) })
                try stream.close()
            } else {
                responseData = Data()
            }
        } catch {
            connection.disconnect()
            throw ApiClientError.fromAndroidError(error)
        }

        // 7. Extract response headers
        let responseHeaders = extractHeaders(from: urlConnection)

        // 8. Disconnect
        connection.disconnect()

        // 9. Log response
        logger.info("Response \(statusCode) for \(requestable.httpMethod.rawValue) \(urlString)")
        if logger.logLevel == .debug,
           let string = String(data: responseData, encoding: .utf8) {
            logger.debug("Response body:\n\(string)")
        }

        // 10. Validate status code
        let requestInfo = RequestInfo(url: urlString,
                                      httpMethod: requestable.httpMethod.rawValue,
                                      headers: requestable.headers,
                                      body: requestable.postBody?.dataPresentation?.data)

        guard (200...299).contains(statusCode) else {
            throw ApiClientError.badStatusCode(statusCode: statusCode,
                                               data: responseData,
                                               responseHeaders: responseHeaders,
                                               request: requestInfo)
        }

        // 11. Parse response
        do {
            return try R.ResponseType(statusCode: statusCode,
                                      headers: responseHeaders,
                                      data: responseData)
        } catch {
            throw ApiClientError.failedToParseResponseData(responseData, error, statusCode)
        }
    }

    private func extractHeaders(from connection: URLConnection) -> [String: String] {
        var headers: [String: String] = [:]
        var index: Int32 = 0
        while true {
            let key = connection.getHeaderFieldKey(index)
            let value = connection.getHeaderField(index)
            guard !key.isEmpty, !value.isEmpty else { break }
            headers[key] = value
            index += 1
        }
        return headers
    }
}

#endif
