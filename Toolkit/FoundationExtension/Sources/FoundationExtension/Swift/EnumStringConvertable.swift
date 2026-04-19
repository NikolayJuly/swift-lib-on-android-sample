// EnumStringConvertable.swift

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public protocol EnumStringConvertible: CustomStringConvertible {
    /// Return string presented type, including types, where enum nested
    /// For example, for enum
    /// class A {
    ///   enum E {
    ///   }
    /// }
    ///
    /// Value should be "A.E". No need to return module name here
    static var typeDescription: String { get }
}

extension EnumStringConvertible {

    // MARK: Standard description generation
    public static var typeStringPresentation: String {
        let typeString = String(reflecting: self)
        let module = typeString.components(separatedBy: ".")[0]
        let typeDescription = self.typeDescription
        return "\(module).\(typeDescription)"
    }

    /// Can be used in override `description` if need more detail only for one value.
    /// Use it for others, where default description is enough
    public static func generateStandardDescription(of enumElement: Self) -> String {
        let reflection = Mirror(reflecting: enumElement)

        guard reflection.children.count == 1 else {
            return "Are you sure \(Self.typeStringPresentation) is enum? \(reflection.children.count)"
        }

        let selfChild = reflection.children.first!

        let selfStringValue: String = selfChild.label!

        let childMirror = Mirror(reflecting: selfChild.value)

        let childrenString = childMirror.children.map { child in
            let labelPart: String
            if let label = child.label {
                labelPart = "\(label):"
            } else {
                labelPart = ""
            }

            let childValueDescription: String = "\(child.value)"

            return "\(labelPart)\(childValueDescription)"
        }.joined(separator: ", ")

        return "\(selfStringValue)(\(childrenString))"
    }
}

extension EnumStringConvertible where Self: RawRepresentable {

    public var description: String {
        return Self.generateStandardDescription(of: self)
    }

    public static func generateStandardDescription(of enumElement: Self) -> String {
        return "\(Self.typeStringPresentation).\(enumElement.rawValue)"
    }
}
