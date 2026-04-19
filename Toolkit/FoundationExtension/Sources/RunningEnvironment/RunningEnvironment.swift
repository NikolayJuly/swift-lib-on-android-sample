// RunningEnvironment.swift

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum RunningEnvironment: Hashable, Sendable {
    case production // app downloaded app store
    case testFlight // app downloaded from test flight or release build for iPhone/Simulator
    case debug // debug on iOS device or simulator
    case testing // running in tests
}

public extension RunningEnvironment {

    static let current: RunningEnvironment = {
        guard !Bool.isTesting else {
            return .testing
        }

        #if DEBUG
            return .debug
        #else

        #if !canImport(FoundationEssentials)
            if Bundle.main.isNonAppStoreBuild {
                return .testFlight
            }
        #endif // !canImport(FoundationEssentials)

        return .production
#endif
    }()
}
