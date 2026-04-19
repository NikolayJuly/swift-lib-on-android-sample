// SoftwareVersion.swift

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct SoftwareVersion: Comparable, Equatable, Sendable {

    internal let digits: [Int]

    /// Digits, separated by '.'
    public init?(_ version: String) {
        let digitsString = version.components(separatedBy: ".")

        let digits: [Int]
        do {
            digits = try digitsString.map { try Int($0).unwrapped() }
        } catch {
            return nil
        }

        self.digits = digits
    }

    public init(digits: [Int]) {
        self.digits = digits
    }

    public static func < (lhs: SoftwareVersion, rhs: SoftwareVersion) -> Bool {

        let length = max(lhs.digits.count, rhs.digits.count)

        let lhsDigits = lhs.digits.rightPadding(ofLength: length, byFilling: 0)
        let rhsDigits = rhs.digits.rightPadding(ofLength: length, byFilling: 0)

        for i in 0..<length {
            let l = lhsDigits[i]
            let r = rhsDigits[i]

            if l == r {
                continue
            }

            return l < r
        }

        return false
    }

    public static func == (lhs: SoftwareVersion, rhs: SoftwareVersion) -> Bool {
        let length = max(lhs.digits.count, rhs.digits.count)

        let lhsDigits = lhs.digits.rightPadding(ofLength: length, byFilling: 0)
        let rhsDigits = rhs.digits.rightPadding(ofLength: length, byFilling: 0)

        for i in 0..<length {
            let l = lhsDigits[i]
            let r = rhsDigits[i]

            if l != r {
                return false
            }
        }

        return true
    }
}
