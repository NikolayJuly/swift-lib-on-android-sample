// Asserts.swift

import Foundation
import XCTest

// TimeIntervals are equal, if abs(lhs - rhs) < 1
public func XCTAssertEqualTimeIntervals(_ lhs: TimeInterval, _ rhs: TimeInterval, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    let diff = abs(lhs - rhs)
    XCTAssertTrue(diff < 1, message(), file: file, line: line)
}


public func XCTAssertEqualDates(_ lhs: Date?, _ rhs: Date, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    guard let lhs = lhs else {
        XCTFail("nil is not equal to \(rhs)", file: file, line: line)
        return
    }
    XCTAssertEqualTimeIntervals(lhs.timeIntervalSince1970, rhs.timeIntervalSince1970)
}

/// Uses NSNull or Void, when value is null. Treat null and missing key as equal
public func XCTAssertEqualJsonObjects(_ lhs: [String: Any], _ rhs: [String: Any], _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    _ = compare2JsonObjects(lhs, rhs, message, path: [], file: file, line: line)
}

public func XCTAssertEqualEventually<T>(_ expression1: @autoclosure () -> T,
                                        _ expression2: @autoclosure () -> T,
                                        _ message: @autoclosure () -> String = "",
                                        timeout: TimeInterval = 1,
                                        file: StaticString = #filePath,
                                        line: UInt = #line) async where T : Equatable {
    let startDate = Date()
    while Date().timeIntervalSince(startDate) < timeout {
        let lhs = expression1()
        let rhs = expression2()
        if lhs == rhs {
            return
        }
        do {
            try await Task.sleep(nanoseconds: UInt64(TimeInterval(1_000_000_000) * 0.05))
        } catch {
            XCTFail("We failed to sleep... which is unexpected", file: file, line: line)
        }
    }
    XCTFail("\(expression1()) is not equal to \(expression2()). \(message())", file: file, line: line)
}

public func XCTAssertEqualEventually<T>(_ expression1: @Sendable () async -> T,
                                        _ expression2: @Sendable () async -> T,
                                        _ message: @autoclosure () -> String = "",
                                        timeout: TimeInterval = 1,
                                        file: StaticString = #filePath,
                                        line: UInt = #line) async where T : Equatable {
    let startDate = Date()
    while Date().timeIntervalSince(startDate) < timeout {
        let lhs = await expression1()
        let rhs = await expression2()
        if lhs == rhs {
            return
        }
        do {
            try await Task.sleep(nanoseconds: UInt64(TimeInterval(1_000_000_000) * 0.05))
        } catch {
            XCTFail("We failed to sleep... which is unexpected", file: file, line: line)
        }
    }
    XCTFail("\(await expression1()) is not equal to \(await expression2()). \(message())", file: file, line: line)
}


func compare2JsonObjects(_ lhs: [String: Any], _ rhs: [String: Any], _ message:  () -> String, path: [Any], file: StaticString, line: UInt) -> Bool {
    let keys = Set(lhs.keys).union(rhs.keys)

    for key in keys {
        var lhsValue = lhs[key]
        var rhsValue = rhs[key]

        if lhsValue is Void || lhsValue is NSNull {
            lhsValue = nil
        }

        if rhsValue is Void || rhsValue is NSNull {
            rhsValue = nil
        }

        guard let lhsValue, let rhsValue else {
            if lhsValue == nil && rhsValue == nil {
                continue
            } else {
                XCTFail("\(message()). In JSON only one of values is nil at path \(path)", file: file, line: line)
                break
            }
        }

        let equal = compare2JsonElements(lhsValue, rhsValue, message, path: path + [key], file: file, line: line)
        if !equal {
            return false
        }
    }

    return true
}

func compare2JsonArrays(_ lhs: [Any], _ rhs: [Any], _ message:() -> String, path: [Any], file: StaticString, line: UInt) -> Bool {
    guard lhs.count == rhs.count else {
        XCTFail("\(message()). Arrays are have equal counts at path \(path): l = \(lhs.count); r = \(rhs.count).", file: file, line: line)
        return false
    }

    for i in 0 ..< lhs.count {
        let l = lhs[i]
        let r = lhs[i]
        let equal = compare2JsonElements(l, r, message, path: path + [i], file: file, line: line)
        if !equal {
            return false
        }
    }
    return true
}

func compare2JsonElements(_ lhs: Any, _ rhs: Any, _ message: () -> String, path: [Any], file: StaticString, line: UInt) -> Bool {

    switch (lhs, rhs) {
    case let (l, r) as (Bool, Bool):
        return check(l: l, r: r, message: message, path: path, file: file, line: line)
    case let (l, r) as (Int64, Int64):
        return check(l: l, r: r, message: message, path: path, file: file, line: line)
    case let (l, r) as (String, String):
        return check(l: l, r: r, message: message, path: path, file: file, line: line)
    case let (l, r) as (Decimal, Decimal):
        return check(l: l, r: r, message: message, path: path, file: file, line: line)
    case let (l, r) as (Double, Double):
        return check(l: l, r: r, message: message, path: path, file: file, line: line)
    case let (l, r) as (String, String):
        return check(l: l, r: r, message: message, path: path, file: file, line: line)
    case let (l, r) as ([Any], [Any]):
        return compare2JsonArrays(l, r, message, path: path, file: file, line: line)
    case let (l, r) as ([String: Any], [String: Any]):
        return compare2JsonObjects(l, r, message, path: path, file: file, line: line)
    default:
        XCTFail("\(message()).Values are not equal at path \(path): l = \(lhs); r = \(rhs).", file: file, line: line)
        return false
    }
}

func check<T: Equatable>(l: T, r: T, message: () -> String, path: [Any], file: StaticString, line: UInt) -> Bool {
    if l == r {
        return true
    }

    XCTFail("\(message()). Values are not equal at path \(path): l = \(l); r = \(r).", file: file, line: line)
    return false
}
