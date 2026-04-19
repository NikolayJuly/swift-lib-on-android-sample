// FetchPokemonsRequest.swift

import Foundation
import NetworkKit

public struct FetchPokemonsRequest: Requestable {

    public typealias PostBodyType = NoPostDataType
    public typealias ResponseType = JSONDecodableResponse<PokemonListResponseDTO>

    public init(limit: Int) {
        var components = URLComponents(string: "https://pokeapi.co/api/v2/pokemon")!
        components.queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        self.url = components.url!
    }

    public let url: URL
    public var httpMethod: HttpMethod { .get }
    public var postBody: NoPostDataType? { nil }
}
