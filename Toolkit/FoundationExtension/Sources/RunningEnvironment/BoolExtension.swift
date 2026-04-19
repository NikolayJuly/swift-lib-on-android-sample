// BoolExtension.swift

#if canImport(Glibc)
import Glibc
#endif

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public extension Bool {
    static let isTesting: Bool = {
        #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
            return NSClassFromString("XCTestCase") != nil
        #else
            // To make it work, on runtimes without obj, you should call tests like this  `$ RUNNING_TESTS=true swift test`
            let env = ProcessInfo.processInfo.environment
            let isRunningTests = env["RUNNING_TESTS"] == "true"
            let isXctestBinary = if CommandLine.arguments.isEmpty {
                false
            } else {
                CommandLine.arguments[0].hasSuffix(".xctest")
            }
            return isRunningTests || isXctestBinary
        #endif
    }()

    static let isSimulator: Bool = {
        #if targetEnvironment(simulator)
            return true
        #else
            return false
        #endif
    }()

    static let isInDebug: Bool = {
#if DEBUG
        return true
#else
        return false
#endif
    }()

    static let isAppExtension: Bool = {
        #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
            Bundle.main.bundleURL.pathExtension == "appex"
        #else
            false
        #endif
    }()

    static let isCliBinary: Bool = {
        #if os(iOS) || os(watchOS) || os(tvOS) || os(Android)
            return false
        #elseif os(Linux)
            return isatty(STDIN_FILENO) != 0
        #else
            var url = URL(fileURLWithPath: Bundle.main.bundlePath)
            for _ in 0...3 {
                if url.pathExtension.lowercased() == "app" {
                    return false
                }
                url.deleteLastPathComponent()
            }
            return true
        #endif
    }()

    static let isiOSAppOnMac: Bool = {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(macOS)
            ProcessInfo.processInfo.isiOSAppOnMac
        #else // os(iOS) || os(tvOS) || os(watchOS) || os(macOS)
            false
        #endif //os(iOS) || os(tvOS) || os(watchOS) || os(macOS)
    }()
}
