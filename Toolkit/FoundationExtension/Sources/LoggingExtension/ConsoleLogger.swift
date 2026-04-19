// ConsoleLogger.swift

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

import Logging

public struct ConsoleLogger: LogHandler {

    public init() {}

    // MARK: LogHandler

    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get {
            metadata[key]
        }
        set {
            metadata[key] = newValue
        }
    }
    
    public var metadata: Logger.Metadata = [:]

    public var logLevel: Logger.Level = .info

    public func log(event: LogEvent) {
        let prefixNeededLevels: [Logger.Level] = [.warning, .error]

        var prefix: String = ""
        if prefixNeededLevels.contains(event.level) {
            prefix = "\(event.file): line \(event.line) :: "
        }

        let dateFormatter = LoggerDateFormatter()
        let dateString = dateFormatter.string(from: Date())
        let resString = dateString + " [\(event.level)] \(prefix)\(event.message)"
        print(resString)
    }
}

