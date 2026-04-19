// PokemonProtoTests.swift

import Foundation
import SwiftProtobuf
import Testing

@testable import PokemonKit

struct PokemonProtoTests {

    /// Roundtrips `PB_PokemonListState` through protobuf binary encoding and decoding.
    /// Breaks if the generated types lose fidelity or if `.proto` field numbers are reused.
    @Test
    func pokemonListStateRoundTrips() throws {
        var state = PB_PokemonListState()
        state.pokemons = [
            makePokemon(id: 1, name: "bulbasaur"),
            makePokemon(id: 25, name: "pikachu"),
        ]
        state.lastRefreshEpochMs = 1_700_000_000_000
        state.loadState = .loaded

        let bytes = try state.serializedBytes() as [UInt8]
        let decoded = try PB_PokemonListState(serializedBytes: bytes)

        #expect(decoded == state)
    }

    // MARK: - Private

    private func makePokemon(id: Int32, name: String) -> PB_Pokemon {
        var pokemon = PB_Pokemon()
        pokemon.id = id
        pokemon.name = name
        pokemon.spriteURL = "https://sprites.example/\(id).png"
        return pokemon
    }
}
