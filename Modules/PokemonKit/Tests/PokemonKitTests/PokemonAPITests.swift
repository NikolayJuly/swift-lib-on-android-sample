// PokemonAPITests.swift

import Foundation
import NetworkKit
import NetworkKitTestsSupport
import Testing

@testable import PokemonKit

struct PokemonAPITests {

    /// Integration: fixture bytes (captured once from https://pokeapi.co/api/v2/pokemon?limit=20)
    /// flow through ApiClient → JSONDecoder → DTO → mapping → domain, producing 20 Pokémon.
    /// Breaks if PokéAPI shape diverges from DTO, if decoding breaks, or if mapping produces wrong ids.
    @Test
    func fetchTopPokemonsDecodesAndMapsFixture() async throws {
        let apiClient = ApiClientMock()
        let fixtureURL = try #require(Bundle.module.url(forResource: "pokemon-list-limit-20",
                                                       withExtension: "json"))
        let fixtureData = try Data(contentsOf: fixtureURL)
        apiClient.stubSuccess(result: fixtureData)
        let sut = PokemonAPIImpl(apiClient: apiClient)

        let pokemons = try await sut.fetchTopPokemons(limit: 20)

        #expect(pokemons.count == 20)
        #expect(pokemons.first?.id == 1)
        #expect(pokemons.first?.name == "bulbasaur")
        #expect(pokemons.first?.spriteURL.absoluteString.hasSuffix("/1.png") == true)
    }
}
