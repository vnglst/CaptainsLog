import CaptainsLogCore
import Foundation

public enum SearchViewState: Equatable {
    case idle
    case preparingModel
    case indexing(message: String, completed: Int, total: Int)
    case searching
    case ready
    case error(String)
}

@MainActor
@Observable
public final class SearchManager {
    typealias SearchFactory = @Sendable (
        String, @escaping @Sendable (Progress) -> Void
    ) async throws -> SemanticSearch

    public var query = ""
    public private(set) var results: [SearchResult] = []
    public private(set) var state: SearchViewState = .idle

    public var isActive: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchTask: Task<Void, Never>?
    private var engine: SemanticSearch?
    private var engineDataDir: String?
    private let debounceInterval: Duration
    private let searchFactory: SearchFactory
    #if DEBUG
    private var isFixtureMode = false
    #endif

    public convenience init() {
        self.init(debounceInterval: .milliseconds(300)) { dataDir, progress in
            try await SemanticSearch.live(dataDir: dataDir, downloadProgress: progress)
        }
    }

    init(debounceInterval: Duration, searchFactory: @escaping SearchFactory) {
        self.debounceInterval = debounceInterval
        self.searchFactory = searchFactory
    }

    #if DEBUG
    func applyFixture(query: String, results: [SearchResult], state: SearchViewState = .ready) {
        searchTask?.cancel()
        isFixtureMode = true
        self.query = query
        self.results = results
        self.state = state
    }
    #endif

    public func updateQuery(_ value: String, dataDir: String) {
        query = value
        searchTask?.cancel()
        #if DEBUG
        if isFixtureMode {
            if !isActive {
                results = []
                state = .idle
            }
            return
        }
        #endif
        guard isActive else {
            results = []
            state = .idle
            return
        }
        let debounceInterval = self.debounceInterval
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: debounceInterval)
            guard !Task.isCancelled, let self else { return }
            await self.performSearch(dataDir: dataDir)
        }
    }

    public func retry(dataDir: String) {
        engine = nil
        engineDataDir = nil
        updateQuery(query, dataDir: dataDir)
    }

    public func invalidateIndex(dataDir: String) {
        guard isActive else { return }
        updateQuery(query, dataDir: dataDir)
    }

    private func performSearch(dataDir: String) async {
        do {
            let search: SemanticSearch
            if let engine, engineDataDir == dataDir {
                search = engine
            } else {
                state = .preparingModel
                search = try await searchFactory(dataDir) { [weak self] _ in
                    Task { @MainActor in self?.state = .preparingModel }
                }
                guard !Task.isCancelled else { return }
                engine = search
                engineDataDir = dataDir
            }

            let matches = try await search.search(query, limit: 20) { [weak self] progress in
                Task { @MainActor in
                    guard let self else { return }
                    switch progress.phase {
                    case .preparingModel: self.state = .preparingModel
                    case .scanning:
                        self.state = .indexing(
                            message: progress.message,
                            completed: progress.completed,
                            total: progress.total
                        )
                    case .indexing:
                        self.state = .indexing(
                            message: progress.message,
                            completed: progress.completed,
                            total: progress.total
                        )
                    case .searching: self.state = .searching
                    }
                }
            }
            guard !Task.isCancelled else { return }
            results = matches
            state = .ready
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            state = .error(error.localizedDescription)
        }
    }
}
