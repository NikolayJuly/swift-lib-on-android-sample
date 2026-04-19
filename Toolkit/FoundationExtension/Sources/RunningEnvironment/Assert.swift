// Assert.swift

#if canImport(FoundationEssentials)
import FoundationEssentials
import Dispatch
#else
import Foundation
#endif

/// Triggers assert if execution is happens on main thread of iOS. On macOS nothing happen
public func assertMainThreadOnIos(_ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    #if os(iOS)
    assert(Thread.isMainThread)
    #endif
}

/// Triggers assert if execution is happens on main thread of iOS. On macOS nothing happen
public func assertMainThreadOrAppExtension(_ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    #if os(iOS)
    assert(Thread.isMainThread || .isAppExtension, file: file, line: line)
    #endif
}

/// It checks:
/// - Thread.isMainThread on Darwin - in apps
/// - dispatchPrecondition(condition: .onQueue(.main)) on Android
public func assertMainThread(_ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
#if DEBUG
    #if os(iOS) || os(tvOS) || os(watchOS) || os(macOS)
    assert(Thread.isMainThread, message(), file: file, line: line)
    #elseif os(Android)
    dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
    #endif
#endif // DEBUG
}

/// Opposite of `assertMainThread`
public func assertOffMainThread(_ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
#if DEBUG
    #if os(iOS) || os(tvOS) || os(watchOS) || os(macOS)
    assert(Thread.isMainThread == false, message(), file: file, line: line)
    #elseif os(Android)
    dispatchPrecondition(condition: .notOnQueue(DispatchQueue.main))
    #endif
#endif // DEBUG
}
