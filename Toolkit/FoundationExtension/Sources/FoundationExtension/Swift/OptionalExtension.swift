// OptionalExtension.swift

import Swift

public extension Optional {

    /// - note: throws if self is .none
    @inlinable
    func unwrapped<T: Error>(otherwise: T) throws(T) -> Wrapped {
        guard case let .some(value) = self else {
            throw otherwise
        }
        return value
    }

    @inlinable
    func unwrapped(_ message: String = "", file: String = #file, function: String = #function, line: Int = #line) throws -> Wrapped {
        guard case let .some(value) = self else {
            throw OptionalExtensionError.optionIsNil(message: message, file: file, function: function, line: line)
        }
        return value
    }
}

public enum OptionalExtensionError: EnumError {
    case optionIsNil(message: String = "", file: String = #file, function: String = #function, line: Int = #line)

    // MARK: EnumError

    public static let typeDescription = "OptionalExtensionError"

    // MARK: CustomNSError

    public var description: String {
        switch self {
        case let .optionIsNil(message, file, function, line):
            let updatedMessage = message.isEmpty ? "" : ". Message: \(message)"
            return "Failed to unwrap in \(file), function: \(function), line: \(line)\(updatedMessage) (OptionalExtensionError.optionIsNil)"
        }
    }

    public var errorCode: Int {
        switch self {
        case .optionIsNil: return 1
        }
    }
}
