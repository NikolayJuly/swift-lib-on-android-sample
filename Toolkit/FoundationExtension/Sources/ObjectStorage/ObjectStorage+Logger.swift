// ObjectStorage+Logger.swift

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Logging
import LoggingExtension

public extension ObjectStorage {
    var logger: Logger {
        Log.shared
    }

    nonisolated
    static func initLogger(_ handlers: [LogHandler]) {
        Log._shared = Logger(label: "SharedLogger", factory: { _ in MultiplexLogHandler(handlers) })
    }

    nonisolated
    func initLogger(_ handlers: [LogHandler]) {
        Self.initLogger(handlers)
    }
}

private struct LoggerKey: ObjectStorageKey {
    typealias Value = Logger
}

public final class Log {
    public static var shared: Logger {
        guard let shared = _shared else {
            fatalError("Make sure to call `initLogger` before using logger")
        }
        return shared
    }

    public static func errorIfNeeded(_ error: Error?, _ file: String = #file, _ function: String = #function, _ line: UInt = #line) {
        guard let errorUnwrapped = error else {
            return
        }
        self.error(errorUnwrapped.errorDescription, file, function, line)
    }

    public static func info(_ message: String, _ file: String = #file, _ function: String = #function, _ line: UInt = #line) {
        shared.info(message, file: file, function: function, line: line)
    }

    public static func error(_ message: String, _ file: String = #file, _ function: String = #function, _ line: UInt = #line) {
        shared.error(message, file: file, function: function, line: line)
    }

    public static func record(_ error: Error, in file: String = #fileID, _ function: String = #function, at line: UInt = #line) {
        let message = "Error :: \(error.errorDescription). error - \(error). In \(file):L\(line), func \(function)"
        self.error(message, file, function, line)
    }

    public static func external(_ message: String, file: String = #fileID, function: String = #function, line: UInt = #line) {
        shared.external(message, file: file, function: function, line: line)
    }

    // Value will be initialized once on app start, after that it is safe to read it form any thread/context
    nonisolated(unsafe)
    fileprivate static var _shared: Logger!

    private init() {}
}

private extension Error {
    var errorDescription: String {
        #if canImport(Darwin)
        localizedDescription
        #else
        "\(self)"
        #endif
    }
}
