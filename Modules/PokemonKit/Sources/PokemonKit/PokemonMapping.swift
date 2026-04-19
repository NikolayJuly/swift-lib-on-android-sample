// PokemonMapping.swift

import Foundation

enum PokemonMapping {

    /// Assumes `summary.url` is the canonical PokéAPI shape `.../pokemon/<id>/`.
    static func pokemon(from summary: PokemonSummaryDTO) -> Pokemon {
        let id = Int(summary.url.lastPathComponent)!
        return Pokemon(id: id,
                       name: summary.name,
                       spriteURL: Pokemon.spriteURL(forID: id))
    }
}
