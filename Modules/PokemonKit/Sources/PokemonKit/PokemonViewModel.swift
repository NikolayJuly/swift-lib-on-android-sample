// PokemonViewModel.swift

import JsonCacheKit
import FileSystemKit
import Foundation
import FoundationExtension
import Logging
import NetworkKit
import PersistenceKit
import Synchronization

public protocol PokemonViewModel: Sendable {
    var state: PB_PokemonListState { get }
    func states() -> any AsyncSequence<PB_PokemonListState, Never>
    func refresh()
}

public final class PokemonViewModelImpl: PokemonViewModel {

    /// Key under which the last successful refresh timestamp (TimeInterval) is persisted.
    static let lastRefreshKey = "com.sample.pokemon-cache.lastRefreshAt"

    @MainActor
    public init(apiClient: ApiClient,
                fileSystemService: FileSystemService,
                keyValueStore: KeyValueStore,
                cacheLocation: CacheLocation,
                workingQueue: DispatchQueue,
                appLifecycleObserver: AppLifecycleObserver,
                logger: Logger) {
        self.keyValueStore = keyValueStore
        self.logger = logger

        // Sync disk read at startup so the VM can render a warm-start snapshot instantly —
        // no need to wait for ServiceWithJsonCacheImpl's async disk fetch.
        let initialDTO = Self.readDTOFromDisk(cacheLocation: cacheLocation, fileSystemService: fileSystemService)
        let initial = Self.makePBState(dto: initialDTO,
                                       lastRefreshAt: Self.readLastRefreshAt(keyValueStore: keyValueStore),
                                       loadState: initialDTO == nil ? .idle : .loaded)
        self.storage = Mutex(Storage(state: initial, continuations: [:]))

        let repository = RepositoryWithJsonCache<PokemonListResponseDTO>(cacheLocation: cacheLocation,
                                                                          fileSystemService: fileSystemService,
                                                                          logger: logger)
        let factory = PokemonListRequestFactoryAdapter(limit: 20)
        let inner = ServiceWithJsonCacheImpl(repository: repository,
                                             requestFactory: factory,
                                             apiClient: apiClient,
                                             workingQueue: workingQueue,
                                             appLifecycleObserver: appLifecycleObserver,
                                             logger: logger)
        self.inner = inner

        // Init is @MainActor, so we can subscribe synchronously here — any observable
        // emissions queued on MainActor by `inner` (initial disk read hop, network success)
        // run only after this init returns, so no race.
        // Using plain `subscribe` (not `subscribeForChangesOnlyAsync`) — we want to know
        // about every `updateCache` call, even when the DTO is equal to the previous one,
        // so that "last refresh" timestamp advances on every successful refresh.
        _ = inner.observableModel.subscribe { [weak self] change in
            self?.handleObservableUpdate(change.newValue)
        }
    }

    // MARK: - PokemonViewModel

    public var state: PB_PokemonListState {
        storage.withLock { $0.state }
    }

    public func states() -> any AsyncSequence<PB_PokemonListState, Never> {
        AsyncStream { continuation in
            let id = UUID()
            let snapshot = storage.withLock { storage -> PB_PokemonListState in
                storage.continuations[id] = continuation
                return storage.state
            }
            continuation.yield(snapshot)
            continuation.onTermination = { [weak self] _ in
                _ = self?.storage.withLock { $0.continuations.removeValue(forKey: id) }
            }
        }
    }

    public func refresh() {
        // Loading spinner only makes sense when there's nothing on screen yet.
        // A refresh over already-loaded data is a silent background reload.
        if state.pokemons.isEmpty {
            pushLoading()
        }
        inner.updateModelFromNetwork()
    }

    // MARK: - Private

    private let inner: ServiceWithJsonCacheImpl<PokemonListResponseDTO, PokemonListRequestFactoryAdapter>
    private let keyValueStore: KeyValueStore
    private let logger: Logger
    private let storage: Mutex<Storage>

    private struct Storage: Sendable {
        var state: PB_PokemonListState
        var continuations: [UUID: AsyncStream<PB_PokemonListState>.Continuation]
    }

    @MainActor
    private func handleObservableUpdate(_ dto: PokemonListResponseDTO?) {
        // `nil` is the transient empty state that precedes the first disk/network load — skip.
        guard let dto else { return }
        let now = Date()
        keyValueStore.set(now.timeIntervalSince1970, forKey: Self.lastRefreshKey)
        let pbState = Self.makePBState(dto: dto, lastRefreshAt: now, loadState: .loaded)
        push(state: pbState)
    }

    private func pushLoading() {
        let loading = storage.withLock { storage -> PB_PokemonListState in
            var new = storage.state
            new.loadState = .loading
            return new
        }
        push(state: loading)
    }

    private func push(state: PB_PokemonListState) {
        let continuations = storage.withLock { storage -> [AsyncStream<PB_PokemonListState>.Continuation] in
            storage.state = state
            return Array(storage.continuations.values)
        }
        for continuation in continuations {
            continuation.yield(state)
        }
    }

    private static func makePBState(dto: PokemonListResponseDTO?,
                                    lastRefreshAt: Date?,
                                    loadState: PB_PokemonListState.LoadState) -> PB_PokemonListState {
        var state = PB_PokemonListState()
        state.pokemons = (dto?.pokemons ?? []).map(makePBPokemon(from:))
        if let lastRefreshAt {
            state.lastRefreshEpochMs = Int64(lastRefreshAt.timeIntervalSince1970 * 1000)
            state.lastRefreshLabel = "Last refresh: \(lastRefreshAt.formatted(date: .abbreviated, time: .shortened))"
        } else {
            state.lastRefreshLabel = "Last refresh: never"
        }
        state.loadState = loadState
        return state
    }

    private static func makePBPokemon(from pokemon: Pokemon) -> PB_Pokemon {
        var pb = PB_Pokemon()
        pb.id = Int32(pokemon.id)
        pb.name = pokemon.name
        pb.spriteURL = pokemon.spriteURL.absoluteString
        return pb
    }

    private static func readLastRefreshAt(keyValueStore: KeyValueStore) -> Date? {
        let timestamp = keyValueStore.double(forKey: lastRefreshKey)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }

    private static func readDTOFromDisk(cacheLocation: CacheLocation,
                                        fileSystemService: FileSystemService) -> PokemonListResponseDTO? {
        let url = cacheLocation.cacheUrl
        guard fileSystemService.fileExists(at: url) else {
            return nil
        }
        guard let data = try? fileSystemService.fileContent(at: url) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PokemonListResponseDTO.self, from: data)
    }
}

// MARK: - Request factory adapter

struct PokemonListRequestFactoryAdapter: RequestFactory, Sendable {
    typealias Request = FetchPokemonsRequest

    let limit: Int

    func make() -> FetchPokemonsRequest {
        FetchPokemonsRequest(limit: limit)
    }
}
