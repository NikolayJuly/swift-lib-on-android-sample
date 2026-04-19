// CollectionExtension.swift

import Swift

public extension Collection {
    func separate(predicate: (Element) -> Bool) -> (matching: [Element], notMatching: [Element]) {
        var groups: ([Element], [Element]) = ([], [])
        for element in self {
            if predicate(element) {
                groups.0.append(element)
            } else {
                groups.1.append(element)
            }
        }
        return groups
    }
}
