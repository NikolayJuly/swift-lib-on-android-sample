// PokemonAPI.swift

import Foundation
import NetworkKit

public protocol PokemonAPI: Sendable {
    func fetchTopPokemons(limit: Int) async throws -> [Pokemon]
}

public final class PokemonAPIImpl: PokemonAPI {

    public init(apiClient: ApiClient) {
        self.apiClient = apiClient
    }

    // MARK: - PokemonAPI

    public func fetchTopPokemons(limit: Int) async throws -> [Pokemon] {
        let request = FetchPokemonsRequest(limit: limit)
        let response = try await apiClient.request(request)
        return response.response.results.map(PokemonMapping.pokemon(from:))
    }

    // MARK: - Private

    private let apiClient: ApiClient
}
