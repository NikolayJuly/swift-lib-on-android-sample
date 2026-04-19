// LoggerExtension.swift

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

import Logging

public extension Logger {

    static let silent = Logger(label: "Silent", factory: { _ in SilentLogger() })

    func recordIfNeeded(_ error: Error?, _ file: String = #file, _ function: String = #function, _ line: UInt = #line) {
        guard let error else {
            return
        }

        record(error, in: file, function, at: line)
    }

    func record(_ error: Error, in file: String = #fileID, _ function: String = #function, at line: UInt = #line) {
        let message: Logger.Message = "Error :: \(error). In \(file):L\(line), func \(function)"
        var metadata = metadataProvider?.get() ?? [String: MetadataValue]()
        metadata.attachedError = error
        self.log(level: .error, message, metadata: metadata, file: file, function: function, line: line)
    }

    func debug(_ message: String,
               metadata: @autoclosure () -> Logger.Metadata? = nil,
               source: @autoclosure () -> String? = nil,
               file: String = #fileID, function: String = #function, line: UInt = #line) {
        let message = Logger.Message(stringLiteral: message)

        debug(message, metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    func info(_ message: String,
              metadata: @autoclosure () -> Logger.Metadata? = nil,
              source: @autoclosure () -> String? = nil,
              file: String = #fileID, function: String = #function, line: UInt = #line) {
        let message = Logger.Message(stringLiteral: message)

        info(message, metadata: metadata(), source: source(), file: file, function: function, line: line)
    }
    
    func error(_ message: String,
               metadata: @autoclosure () -> Logger.Metadata? = nil,
               source: @autoclosure () -> String? = nil,
               file: String = #fileID, function: String = #function, line: UInt = #line) {
        let message = Logger.Message(stringLiteral: message)

        error(message, metadata: metadata(), source: source(), file: file, function: function, line: line)
    }

    func external(_ message: String, file: String = #fileID, function: String = #function, line: UInt = #line) {
        let message = Logger.Message(stringLiteral: message)

        var metadata = [String: MetadataValue]()
        metadata.isForExternalLogger = true

        info(message, metadata: metadata, source: nil, file: file, function: function, line: line)
    }
}

public extension Dictionary<String, Logger.MetadataValue> {
    var isForExternalLogger: Bool {
        get {
            guard case let .stringConvertible(stringConvertible) = self[.loggerExternalKey],
                  let bool = stringConvertible as? Bool else {
                return false
            }

            return bool
        }
        set {
            self[.loggerExternalKey] = .stringConvertible(newValue)
        }
    }

    var attachedError: Error? {
        get {
            guard case let .string(errorBase64) = self[.loggerErrorKey] else {
                return nil
            }

            let errorData = Data(base64Encoded: errorBase64)!
            let jsonError = try! JSONDecoder().decode(JsonError.self, from: errorData)
            return jsonError.createError()
        }
        set {
            guard let error = newValue else {
                self[.loggerErrorKey] = nil
                return
            }

            let jsonError = JsonError(error)
            let errorData = try! JSONEncoder().encode(jsonError)
            let errorBase64 = errorData.base64EncodedString()
            self[.loggerErrorKey] = .string(errorBase64)
        }
    }
}

private extension String {
    static let loggerExternalKey = "LS_LoggerExternalTagKey"
    static let loggerErrorKey = "LS_LoggerErrorTagKey"
}

#if canImport(ObjectiveC)

private struct JsonError: Codable {
    init(_ error: Error) {
        let nsError = error as NSError
        self.domain = nsError.domain
        self.code = nsError.code
        self.userInfo = nsError.userInfo.mapValues { "\($0)" }
    }

    func createError() -> Error {
        NSError(domain: domain, code: code, userInfo: userInfo)
    }

    private let domain: String
    private let code: Int
    private let userInfo: [String: String]
}

#else

private struct JsonError: Codable {
    init(_ error: Error) {
        self.type = String(describing: Swift.type(of: error))
        self.description = "\(error)"
    }

    func createError() -> Error {
        StoredError(type: type, description: description)
    }

    private let type: String
    private let description: String
}

private struct StoredError: Error, CustomStringConvertible {
    let type: String
    let description: String
}

#endif

