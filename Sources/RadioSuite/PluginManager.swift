import Foundation
import RadioPluginKit

/// Host version, for plugin `minHostVersion` compatibility checks.
enum HostInfo {
    static let version = "1.0"
}

/// Where a discovered plugin came from.
enum PluginSourceKind: String { case builtIn, installed, dev }

/// Lifecycle/availability state of a discovered plugin.
enum PluginStatus: Equatable {
    case ready                    // loadable in-process now (built-in)
    case discovered               // installed & compatible, but runs out-of-process (Phase 3 / ExtensionKit)
    case incompatible(String)     // manifest rejects this host (reason)
}

/// One known plugin from any source. `make` is non-nil only when the plugin can be
/// instantiated in-process right now (built-in tier).
struct PluginEntry: Identifiable {
    let manifest: RadioPluginManifest
    let sourceKind: PluginSourceKind
    let status: PluginStatus
    let make: (@MainActor () -> any RadioPlugin)?
    var id: String { manifest.id }

    /// Can this plugin be shown as an active tab (loadable + a factory available)?
    var isRunnable: Bool { status == .ready && make != nil }
}

/// A provider of plugins (built-in, installed-on-disk, sideloaded…).
@MainActor protocol PluginSource {
    var kind: PluginSourceKind { get }
    func discover() -> [PluginEntry]
}

/// Discovers installable plugins on disk by reading their `plugin.json` manifest —
/// WITHOUT loading any code. Each becomes a `.discovered` entry (running it is the
/// out-of-process ExtensionKit tier, Phase 3) or `.incompatible` if the manifest
/// rejects this host.
@MainActor struct InstalledPluginSource: PluginSource {
    let kind: PluginSourceKind
    let directory: URL

    init(kind: PluginSourceKind = .installed, directory: URL) {
        self.kind = kind
        self.directory = directory
    }

    /// Default install location: ~/Library/Application Support/AmateurRadioSuite/Plugins
    static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("AmateurRadioSuite/Plugins", isDirectory: true)
    }

    func discover() -> [PluginEntry] {
        let fm = FileManager.default
        guard let subdirs = try? fm.contentsOfDirectory(at: directory,
                                                        includingPropertiesForKeys: [.isDirectoryKey],
                                                        options: [.skipsHiddenFiles]) else { return [] }
        var out: [PluginEntry] = []
        for dir in subdirs {
            let manifestURL = dir.appendingPathComponent("plugin.json")
            guard let data = try? Data(contentsOf: manifestURL),
                  let manifest = try? JSONDecoder().decode(RadioPluginManifest.self, from: data)
            else { continue }
            out.append(PluginEntry(manifest: manifest, sourceKind: kind,
                                   status: Self.status(for: manifest), make: nil))
        }
        return out
    }

    static func status(for manifest: RadioPluginManifest) -> PluginStatus {
        if SemanticVersion.compare(HostInfo.version, manifest.minHostVersion) == .orderedAscending {
            return .incompatible("requires host \(manifest.minHostVersion)+")
        }
        // Installed plugins run out-of-process (ExtensionKit) — not loadable in-process yet.
        return .discovered
    }
}

/// Merges all plugin sources, owns enable/disable state (persisted), and publishes the
/// resulting entries. The single source of truth for "what plugins exist" — adding an
/// installed plugin requires no recompile of the container.
@MainActor final class PluginManager: ObservableObject {
    @Published private(set) var entries: [PluginEntry] = []

    private let sources: [PluginSource]
    private let disabledKey = "suite.disabledPlugins"
    private let store: UserDefaults

    init(sources: [PluginSource], store: UserDefaults = .standard) {
        self.sources = sources
        self.store = store
    }

    private var disabledIDs: Set<String> {
        get { Set(store.stringArray(forKey: disabledKey) ?? []) }
        set { store.set(Array(newValue), forKey: disabledKey) }
    }

    func isEnabled(_ id: String) -> Bool { !disabledIDs.contains(id) }

    func setEnabled(_ enabled: Bool, for id: String) {
        var d = disabledIDs
        if enabled { d.remove(id) } else { d.insert(id) }
        disabledIDs = d
        objectWillChange.send()
    }

    /// Re-scan all sources. Built-in entries win on id collisions (a malicious installed
    /// plugin can't shadow a first-party one).
    func reload() {
        var byID: [String: PluginEntry] = [:]
        for source in sources {
            for entry in source.discover() {
                // Built-in entries win on id collisions; otherwise first writer wins.
                if entry.sourceKind == .builtIn || byID[entry.id] == nil {
                    byID[entry.id] = entry
                }
            }
        }
        entries = byID.values.sorted { $0.manifest.name < $1.manifest.name }
    }

    /// Plugins eligible to appear as active tabs: enabled + runnable in-process.
    var activeEntries: [PluginEntry] {
        entries.filter { isRunnable($0) }
    }

    func isRunnable(_ entry: PluginEntry) -> Bool {
        entry.isRunnable && isEnabled(entry.id)
    }
}

/// Minimal dotted-numeric semantic-version comparison ("1.2" vs "1.10").
enum SemanticVersion {
    static func compare(_ a: String, _ b: String) -> ComparisonResult {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x < y ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }
}
