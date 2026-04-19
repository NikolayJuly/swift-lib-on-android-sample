// ContentView.swift

import PokemonKit
import SwiftUI

struct ContentView: View {

    let viewModel: any PokemonViewModel

    @State private var state: PB_PokemonListState = .init()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                if state.loadState == .loading {
                    ProgressView().padding(8)
                }
                grid
            }
            .navigationTitle("Pokemon")
            .toolbar {
                Button("Refresh") {
                    viewModel.refresh()
                }
            }
        }
        .task {
            for await newState in viewModel.states() {
                state = newState
            }
        }
    }

    // MARK: - Private

    private var header: some View {
        Text(state.lastRefreshLabel)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 8)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(state.pokemons, id: \.id) { pokemon in
                    PokemonCell(pokemon: pokemon)
                }
            }
            .padding(12)
        }
    }
}
