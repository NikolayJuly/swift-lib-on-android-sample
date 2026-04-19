// XCTestCaseExtension.swift

import Foundation
import XCTest

public extension XCTestCase {

    @available(*, noasync, message: "Use async version of this function")
    func wait(delay: TimeInterval) {
        let exp = XCTestExpectation(delay: delay)
        wait(for: [exp], timeout: 2 * delay + 0.2)
    }

    func waitAsync(delay: TimeInterval) async {
        let exp = XCTestExpectation(delay: delay)
        await fulfillment(of: [exp], timeout: 2 * delay + 0.2)
    }

    /// Right now, if declare test as `async` it will block main thread. Because of this tests should not be async, you have to run task and wait
    func executeAndWait<T>(_ block: @Sendable @escaping () async throws -> T, file: String = #file, line: Int = #line) throws -> T {
        let expectation = expectation(description: "execute async from \(file):L\(line)")

        @Atomic var executionResult: Result<T, Error>?
        Task { [_executionResult] in
            do {
                let t = try await block()
                _executionResult.wrappedValue = .success(t)
            } catch {
                _executionResult.wrappedValue = .failure(error)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        let result = try XCTUnwrap(_executionResult.wrappedValue)
        switch result {
        case let .success(t):
            return t
        case let .failure(error):
            throw error
        }
    }

    func executeAndWait<T>(on queue: DispatchQueue,
                           _ block: @Sendable @escaping () throws -> T,
                           file: String = #file,
                           line: Int = #line) throws -> T {
        let expectation = expectation(description: "Execute async from \(file):L\(line)")

        @Atomic
        var executionResult: Result<T, Error>?
        queue.async { [_executionResult] in
            do {
                let t = try block()
                _executionResult.wrappedValue = .success(t)
            } catch {
                _executionResult.wrappedValue = .failure(error)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        let result = try XCTUnwrap(executionResult)
        switch result {
        case let .success(t):
            return t
        case let .failure(error):
            throw error
        }
    }

    @discardableResult
    func waitTillNotNill<T>(_ block: @Sendable @escaping () -> T?, dispatchQueue: DispatchQueue, file: String = #file, function: String = #function, line: Int = #line) throws -> T {
        let expectation = XCTestExpectation(predicate: { block() != nil },
                                            dispatchQueue: dispatchQueue,
                                            description: "Wating till not nill from \(file):L\(line)")
        wait(for: [expectation], timeout: 1)
        return try XCTUnwrap(block())
    }

    func waitTillTrue(_ block: @Sendable @escaping () -> Bool, dispatchQueue: DispatchQueue, file: String = #file, line: Int = #line) {
        let expectation = XCTestExpectation(predicate: block,
                                            dispatchQueue: dispatchQueue,
                                            description: "Wating till true from \(file):L\(line)")
        wait(for: [expectation], timeout: 1)
    }

    @MainActor
    func waitTillTrue(_ block: @MainActor @escaping () -> Bool, file: String = #file, line: Int = #line) {
        let expectation = XCTestExpectation(predicate: block, description: "Wating till true from \(file):L\(line)")
        wait(for: [expectation], timeout: 1)
    }

    func expect(checkInterval: TimeInterval = 0.05,
                timeout: TimeInterval = 1,
                _ predicate: @Sendable () throws -> Bool,
                file: StaticString = #filePath,
                line: UInt = #line) async throws {
        let startDate = Date()
        while Date().timeIntervalSince(startDate) < timeout {
            let res = try predicate()
            if res {
                return
            }
            try await Task.sleep(nanoseconds: UInt64(TimeInterval(1_000_000_000) * checkInterval))
        }
        XCTFail("Failed expectation for predicated", file: file, line: line)
    }
}
