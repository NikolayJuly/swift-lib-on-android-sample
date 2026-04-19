// PokemonCell.swift

import PokemonKit
import SwiftUI

struct PokemonCell: View {

    let pokemon: PB_Pokemon

    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: URL(string: pokemon.spriteURL)) { image in
                image.resizable().aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
            .frame(height: 96)
            Text(pokemon.name.capitalized)
                .font(.callout)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
