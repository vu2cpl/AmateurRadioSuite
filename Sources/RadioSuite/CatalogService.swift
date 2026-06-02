import Foundation
import Combine

/// Publishes the plugin catalog the Browse UI shows. The catalog is the merge of two things:
///
///  - **local entries** — plugins the user added by browsing a `.radioplugin` file
///    (persisted; this is the primary, offline-first source);
///  - **remote sources** — optional catalog `.json` URLs the user subscribes to.
///
/// The suite ships with neither, so it starts empty and clean; the user populates the catalog
/// by browsing plugin files. Both the source list and the local entries are persisted.
@MainActor
final class CatalogService: ObservableObject {
    /// Merged, sorted catalog (local entries win on id collisions).
    @Published private(set) var entries: [CatalogEntry] = []
    /// Plugins added by browsing a local `.radioplugin` file.
    @Published private(set) var localEntries: [CatalogEntry] = []
    @Published private(set) var lastError: String?
    @Published var sources: [URL] {
        didSet { store.set(sources.map(\.absoluteString), forKey: sourcesKey) }
    }

    private var remoteEntries: [CatalogEntry] = []
    private let store: UserDefaults
    private let sourcesKey = "suite.catalogSources"
    private let localKey = "suite.localCatalog"
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
        if let data = store.data(forKey: localKey),
           let decoded = try? JSONDecoder().decode([CatalogEntry].self, from: data) {
            self.localEntries = decoded
        }
        recompute()
    }

    // MARK: - Remote sources

    func addSource(_ url: URL) {
        guard !sources.contains(url) else { return }
        sources.append(url)
    }

    func removeSource(_ url: URL) {
        sources.removeAll { $0 == url }
    }

    /// Refresh all remote sources; later sources win on duplicate plugin ids. Bad sources are
    /// skipped (surfaced via `lastError`) rather than failing the whole refresh. Local entries
    /// are always included.
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
        remoteEntries = Array(byID.values)
        lastError = errors.isEmpty ? nil : errors.joined(separator: "\n")
        recompute()
    }

    // MARK: - Local entries (browsed plugin files)

    /// Add (or replace, by id) a plugin the user browsed from a file. Persisted.
    func addLocalEntry(_ entry: CatalogEntry) {
        localEntries.removeAll { $0.id == entry.id }
        localEntries.append(entry)
        persistLocal()
        recompute()
    }

    func removeLocalEntry(id: String) {
        localEntries.removeAll { $0.id == id }
        persistLocal()
        recompute()
    }

    func isLocal(_ id: String) -> Bool { localEntries.contains { $0.id == id } }

    private func persistLocal() {
        store.set(try? JSONEncoder().encode(localEntries), forKey: localKey)
    }

    // MARK: -

    private func recompute() {
        var byID: [String: CatalogEntry] = [:]
        for entry in remoteEntries { byID[entry.id] = entry }
        for entry in localEntries { byID[entry.id] = entry }   // local wins on collision
        entries = byID.values.sorted { $0.name < $1.name }
    }
}
