// PokemonListResponseDTO.swift

import Foundation

public struct PokemonListResponseDTO: Codable, Equatable, Sendable {

    public let results: [PokemonSummaryDTO]

    public init(results: [PokemonSummaryDTO]) {
        self.results = results
    }

    /// Maps the DTO list to domain `[Pokemon]` so consumers don't need to touch DTO types directly.
    public var pokemons: [Pokemon] {
        results.map(PokemonMapping.pokemon(from:))
    }
}

public struct PokemonSummaryDTO: Codable, Equatable, Sendable {

    public let name: String
    public let url: URL

    public init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}
