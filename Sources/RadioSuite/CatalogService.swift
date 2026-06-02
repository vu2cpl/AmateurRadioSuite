import Foundation
import Combine

/// Fetches and merges plugin catalogs from one or more sources (the official catalog plus
/// any custom URLs the user adds). Source list is persisted.
@MainActor
final class CatalogService: ObservableObject {
    @Published private(set) var entries: [CatalogEntry] = []
    @Published private(set) var lastError: String?
    @Published var sources: [URL] {
        didSet { store.set(sources.map(\.absoluteString), forKey: sourcesKey) }
    }

    private let store: UserDefaults
    private let sourcesKey = "suite.catalogSources"
    private let fetch: (URL) async throws -> Data

    /// `fetch` is injectable for tests (default reads the URL, http(s) or file://).
    init(store: UserDefaults = .standard,
         defaultSources: [URL] = [],
         fetch: @escaping (URL) async throws -> Data = { try Data(contentsOf: $0) }) {
        self.store = store
        self.fetch = fetch
        if let saved = store.stringArray(forKey: sourcesKey) {
            self.sources = saved.compactMap(URL.init(string:))
        } else {
            self.sources = defaultSources
        }
    }

    func addSource(_ url: URL) {
        guard !sources.contains(url) else { return }
        sources.append(url)
    }

    func removeSource(_ url: URL) {
        sources.removeAll { $0 == url }
    }

    /// Refresh all sources; later sources win on duplicate plugin ids. Bad sources are
    /// skipped (surfaced via `lastError`) rather than failing the whole refresh.
    func refresh() async {
        var byID: [String: CatalogEntry] = [:]
        var errors: [String] = []
        for source in sources {
            do {
                let data = try await fetch(source)
                let catalog = try JSONDecoder().decode(PluginCatalog.self, from: data)
                for entry in catalog.plugins { byID[entry.id] = entry }
            } catch {
                errors.append("\(source.lastPathComponent): \(error.localizedDescription)")
            }
        }
        entries = byID.values.sorted { $0.name < $1.name }
        lastError = errors.isEmpty ? nil : errors.joined(separator: "\n")
    }
}
