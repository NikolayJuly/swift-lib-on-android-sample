// EnumError.swift

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Should be used to simplify error creation
/// If some nested value need a special presentation, confirm it to `CustomErrorPresentation` and override


#if !canImport(FoundationEssentials)
public protocol EnumError: LocalizedError, CustomNSError, EnumStringConvertible {}
public extension EnumError {
    var errorUserInfo: [String : Any] {
        return [NSLocalizedDescriptionKey: description]
    }
}
#else  // build with OSS compiler
// If we see `FoundationEssentials` it means, we are in oss toolchain. Lets avoid full Foundation dependency
public protocol EnumError: LocalizedError, EnumStringConvertible {}
#endif // !canImport(FoundationEssentials)

public extension EnumError {

    var description: String {
        return Self.typeStringPresentation + "." + Self.generateStandardDescription(of: self)
    }

    var errorDescription: String? {
        description
    }

    static var errorDomain: String {
        return "ErrorDomain:\(typeDescription)"
    }

    var errorCode: Int {
        return 0
    }
}

