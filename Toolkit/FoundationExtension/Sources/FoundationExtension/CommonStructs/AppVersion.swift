// AppVersion.swift

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Version, were all elements are integers, not containing build
public struct AppVersion: Comparable, Equatable, Sendable {

    public var string: String {
        let threeDigits = softwareVersion.digits.rightPadding(ofLength: 3, byFilling: 0)
        return threeDigits.map { "\($0)" }.joined(separator: ".")
    }

    /// 3-4 digits, separated by '.', 4th one will be ignored
    public init?(_ version: String) {
        guard let softwareVersion = SoftwareVersion(version) else {
            return nil
        }

        guard softwareVersion.digits.count >= 3 else {
            return nil
        }

        self.softwareVersion = softwareVersion
    }

    public init(digits: [Int]) {
        self.softwareVersion = SoftwareVersion(digits: digits)
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        lhs.softwareVersion == rhs.softwareVersion
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        lhs.softwareVersion < rhs.softwareVersion
    }

    // MARK: Private

    private let softwareVersion: SoftwareVersion
}



