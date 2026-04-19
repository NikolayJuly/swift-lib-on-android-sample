// PokemonSampleApp.swift

import PokemonKit
import SwiftUI

@main
struct PokemonSampleApp: App {

    private let viewModel = PokemonViewModelImpl.makeDefault()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
