// XCTestExtension.swift

import Foundation
import XCTest

public func XCTAssertThrowsError<T>(_ expression: @autoclosure @Sendable () async throws -> T,
                                    _ message: @autoclosure () -> String = "",
                                    file: StaticString = #filePath,
                                    line: UInt = #line,
                                    _ errorHandler: (_ error: Error) -> Void = { _ in }) async {
    do {
        _ = try await expression()
        XCTFail(message(), file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
