// Pokemon.swift

import Foundation

public struct Pokemon: Codable, Equatable, Sendable {

    public let id: Int
    public let name: String
    public let spriteURL: URL

    public init(id: Int, name: String, spriteURL: URL) {
        self.id = id
        self.name = name
        self.spriteURL = spriteURL
    }

    static func spriteURL(forID id: Int) -> URL {
        URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(id).png")!
    }
}
