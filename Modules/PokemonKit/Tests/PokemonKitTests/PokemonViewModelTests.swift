// PokemonViewModelTests.swift

import JsonCacheKit
import FileSystemKit
import FileSystemKitTestsSupport
import Foundation
import Logging
import NetworkKit
import NetworkKitTestsSupport
import PersistenceKit
import PersistenceKitTestsSupport
import Testing

@testable import PokemonKit

@MainActor
struct PokemonViewModelTests {

    /// Cold start (no disk, no KV): network returns 20 pokemons. VM ends up with LOADED + 20 items
    /// and a non-empty lastRefreshLabel.
    @Test
    func coldStartFillsStateWith20Pokemons() async throws {
        let env = try makeEnvironment()
        env.apiClient.stubSuccess(result: try fixtureData())
        let sut = makeSut(env: env)

        let finalState = try await waitForState(sut) { $0.pokemons.count == 20 }

        #expect(finalState.loadState == .loaded)
        #expect(finalState.pokemons.count == 20)
        #expect(finalState.pokemons.first?.name == "bulbasaur")
        #expect(finalState.lastRefreshEpochMs > 0)
        #expect(finalState.lastRefreshLabel.hasPrefix("Last refresh: "))
        #expect(finalState.lastRefreshLabel != "Last refresh: never")
    }

    /// Warm start: disk has 5 pokemons, KV has an old timestamp, network is "down".
    /// Sync disk read in init means `sut.state` is already populated — no awaiting.
    @Test
    func warmStartShowsCachedPokemonsImmediatelyFromDisk() async throws {
        let env = try makeEnvironment()
        try seedDisk(on: env, summaries: makeSummaries(count: 5))
        env.keyValueStore.set(1_000.0, forKey: PokemonViewModelImpl.lastRefreshKey)
        env.apiClient.stubFailure(result: .generalNetworkError(URLError(.notConnectedToInternet)))
        let sut = makeSut(env: env)

        let state = sut.state

        #expect(state.loadState == .loaded)
        #expect(state.pokemons.count == 5)
        #expect(state.pokemons.first?.name == "pokemon-1")
        #expect(state.lastRefreshEpochMs == 1_000 * 1_000)
        #expect(state.lastRefreshLabel.hasPrefix("Last refresh: "))
    }

    /// Warm start + refresh: disk has 5, network returns 20. Observed sequence shows cached 5
    /// first, then 20 after refresh completes. lastRefreshEpochMs grows past the seeded value.
    @Test
    func warmStartThenRefreshEmitsCachedThenNetworkOverridesDisk() async throws {
        let env = try makeEnvironment()
        try seedDisk(on: env, summaries: makeSummaries(count: 5))
        env.keyValueStore.set(1_000.0, forKey: PokemonViewModelImpl.lastRefreshKey)
        env.apiClient.stubSuccess(result: try fixtureData())
        let sut = makeSut(env: env)

        let initial = sut.state
        #expect(initial.pokemons.count == 5)

        let finalState = try await waitForState(sut) { $0.pokemons.count == 20 }

        #expect(finalState.loadState == .loaded)
        #expect(finalState.pokemons.first?.name == "bulbasaur")
        #expect(finalState.lastRefreshEpochMs > initial.lastRefreshEpochMs)
    }

    /// Regression: two consecutive refreshes returning identical data still advance
    /// lastRefreshEpochMs each time. Ensures we're observing via plain `subscribe`
    /// (not `subscribeForChangesOnlyAsync`) so unchanged DTOs still bump the timestamp.
    @Test
    func repeatedRefreshWithSameDataStillAdvancesTimestamp() async throws {
        let env = try makeEnvironment()
        env.apiClient.stubSuccess(result: try fixtureData())
        let sut = makeSut(env: env)

        let first = try await waitForState(sut) { $0.pokemons.count == 20 }
        let firstEpoch = first.lastRefreshEpochMs
        #expect(firstEpoch > 0)

        try await Task.sleep(for: .milliseconds(20))

        sut.refresh()
        let second = try await waitForState(sut) { $0.lastRefreshEpochMs > firstEpoch }

        #expect(second.pokemons.count == 20)
        #expect(second.lastRefreshEpochMs > firstEpoch)
    }

    // MARK: - Private

    private struct Environment {
        let apiClient: ApiClientMock
        let fileSystem: InMemoryFileSystemService
        let keyValueStore: KeyValueStoreMock
        let cacheURL: URL
        let appContainerURL: URL
        let workingQueue: DispatchQueue

        var cacheLocation: CacheLocation {
            CacheLocation(cacheUrl: cacheURL, appContainerFolderUrl: appContainerURL)
        }
    }

    private func makeEnvironment() throws -> Environment {
        let root = URL(filePath: "/memfs")
        let fileSystem = InMemoryFileSystemService(rootUrl: root, appRootContainer: root)
        let libraryURL = fileSystem.libraryFolderUrl
        try fileSystem.createEmptyFolder(at: libraryURL)
        return Environment(apiClient: ApiClientMock(),
                           fileSystem: fileSystem,
                           keyValueStore: KeyValueStoreMock(),
                           cacheURL: libraryURL.appendingPathComponent("pokemon-cache.json", isDirectory: false),
                           appContainerURL: libraryURL,
                           workingQueue: DispatchQueue(label: "pokemon-vm-test"))
    }

    private func makeSut(env: Environment) -> PokemonViewModelImpl {
        PokemonViewModelImpl(apiClient: env.apiClient,
                             fileSystemService: env.fileSystem,
                             keyValueStore: env.keyValueStore,
                             cacheLocation: env.cacheLocation,
                             workingQueue: env.workingQueue,
                             appLifecycleObserver: NoOpAppLifecycleObserver(),
                             logger: Logger(label: "test"))
    }

    private func fixtureData() throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "pokemon-list-limit-20",
                                                 withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func makeSummaries(count: Int) -> [PokemonSummaryDTO] {
        (1...count).map { i in
            PokemonSummaryDTO(name: "pokemon-\(i)",
                              url: URL(string: "https://pokeapi.co/api/v2/pokemon/\(i)/")!)
        }
    }

    private func seedDisk(on env: Environment, summaries: [PokemonSummaryDTO]) throws {
        let dto = PokemonListResponseDTO(results: summaries)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(dto)
        try env.fileSystem.createAllSubfolders(forFile: env.cacheURL, in: env.appContainerURL)
        try env.fileSystem.write(data: data, to: env.cacheURL)
    }

    private func waitForState(_ sut: PokemonViewModel,
                              matching predicate: @Sendable @escaping (PB_PokemonListState) -> Bool,
                              timeout: Duration = .seconds(3)) async throws -> PB_PokemonListState {
        try await withThrowingTaskGroup(of: PB_PokemonListState?.self) { group in
            group.addTask {
                for await state in sut.states() where predicate(state) {
                    return state
                }
                return nil
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                return nil
            }
            defer { group.cancelAll() }
            for try await result in group {
                if let result {
                    return result
                }
            }
            throw TimedOut()
        }
    }

    private struct TimedOut: Error {}
}
