// LoggerDateFormatter.swift

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

package protocol LoggerDateFormatting: Sendable {
    func string(from date: Date) -> String
    func date(from string: String) -> Date?
}

#if os(Android) || os(Linux)

package struct LoggerDateFormatter: LoggerDateFormatting {

    package init() {}

    package func string(from date: Date) -> String {
        date.ISO8601Format()
    }

    package func date(from string: String) -> Date? {
        try? Date(string, strategy: .iso8601)
    }
}

#else

package struct LoggerDateFormatter: LoggerDateFormatting {
    package init() {}

    package func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    package func date(from string: String) -> Date? {
        formatter.date(from: string)
    }

    // MARK: Private

    private let formatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH-mm-ss'Z'"
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = Calendar(identifier: .gregorian)
        return df
    }()
}

#endif
