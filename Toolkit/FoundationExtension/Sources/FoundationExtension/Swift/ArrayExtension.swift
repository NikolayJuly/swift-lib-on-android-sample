// ArrayExtension.swift

import Swift

public extension Array {
    /// If `self.count` > length, array will be cut to `length`.
    @inlinable
    func rightPadding(ofLength length: Int, byFilling element: Element) -> [Element] {
        guard self.count < length else {
            return Array(self[..<length])
        }

        var resultArray = self
        while resultArray.count < length {
            resultArray.append(element)
        }

        return resultArray
    }
}
