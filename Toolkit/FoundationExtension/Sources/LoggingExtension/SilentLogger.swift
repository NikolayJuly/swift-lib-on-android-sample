// SilentLogger.swift

import Foundation
import Logging

public struct SilentLogger: LogHandler, @unchecked Sendable {
    public init() {}

    // MARK: SilentLogger

    public var metadata: Logger.Metadata = [:]

    public subscript(metadataKey _: String) -> Logger.Metadata.Value? {
        get { nil }
        set {}
    }

    public var logLevel: Logger.Level = .error

    public func log(event: LogEvent) {}
}
