import SwiftUI
import RadioPluginKit

/// Owns the plugin manager, lazily instantiates active plugins, caches their root
/// views, and tracks the active selection. Views/instances are built once and kept
/// so switching tabs never recreates a plugin or drops its connection.
@MainActor
final class SuiteModel: ObservableObject {
    let host = SuitePluginHost()
    let manager: PluginManager
    let supervisor = PluginSupervisor()
    let catalog: CatalogService

    @Published var selection: String = ""
    /// Drives the command-palette sheet (toggled from the menu / ⌘⇧P).
    @Published var paletteOpen = false

    private let selectionKey = "suite.lastSelection"

    /// Plain, view-friendly description of an active plugin for List/TabView.
    struct Entry: Identifiable, Hashable {
        let id: String
        let title: String
        let systemImage: String
    }

    private var instances: [String: any RadioPlugin] = [:]
    private var cache: [String: AnyView] = [:]
    private var activated: Set<String> = []

    init() {
        let supervisor = self.supervisor
        // No built-in source: the host links no plugin apps. Plugins are discovered
        // on disk (installed/sideloaded) and run out-of-process via ExtensionKit.
        manager = PluginManager(sources: [
            InstalledPluginSource(directory: InstalledPluginSource.defaultDirectory()),
        ])
        manager.isQuarantined = { supervisor.isQuarantined($0) }   // quarantined → drop from active
        catalog = CatalogService(defaultSources: [
            URL(string: "https://raw.githubusercontent.com/VU3ESV/AmateurRadioSuite/main/docs/catalog/catalog.json")!
        ])
        manager.reload()
        selection = Self.restoredSelection(saved: UserDefaults.standard.string(forKey: selectionKey),
                                           active: manager.activeEntries.map(\.id))
    }

    /// Restore the last-active plugin if it's still available, else the first, else none.
    static func restoredSelection(saved: String?, active: [String]) -> String {
        (saved.flatMap { active.contains($0) ? $0 : nil }) ?? active.first ?? ""
    }

    // MARK: - Install / uninstall (Phase 4)

    private var pluginsDir: URL { InstalledPluginSource.defaultDirectory() }

    /// Installed version of a plugin id, if present (for catalog update detection).
    func installedVersion(id: String) -> String? {
        manager.entries.first { $0.id == id }?.manifest.version
    }

    /// Download + install a catalog entry, then rescan.
    func install(_ entry: CatalogEntry) async throws {
        guard let url = URL(string: entry.url) else { return }
        let data = try Data(contentsOf: url)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(entry.id)-\(UUID().uuidString).radioplugin")
        try data.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try PackageInstaller.install(localPackage: tmp, expectedSHA256: entry.sha256, into: pluginsDir)
        manager.reload(); reconcile()
    }

    /// Sideload a local `.radioplugin` (no catalog checksum), then rescan.
    func installFromFile(_ fileURL: URL) throws {
        try PackageInstaller.install(localPackage: fileURL, expectedSHA256: nil, into: pluginsDir)
        manager.reload(); reconcile()
    }

    func uninstall(id: String) throws {
        try PackageInstaller.uninstall(id: id, from: pluginsDir)
        manager.reload(); reconcile()
    }

    func isInstalledFromDisk(_ id: String) -> Bool {
        manager.entries.first { $0.id == id }?.sourceKind == .installed
    }

    /// Active (enabled + runnable) plugins, as tab/sidebar entries.
    var entries: [Entry] {
        manager.activeEntries.map { Entry(id: $0.id, title: $0.manifest.name, systemImage: $0.manifest.systemImage) }
    }

    private func instance(for id: String) -> (any RadioPlugin)? {
        if let p = instances[id] { return p }
        guard let entry = manager.activeEntries.first(where: { $0.id == id }), let make = entry.make
        else { return nil }
        let p = make()
        instances[id] = p
        return p
    }

    func plugin(for id: String) -> (any RadioPlugin)? { instance(for: id) }

    /// Cached, lazily built root view for a plugin.
    func view(for id: String) -> AnyView {
        if let v = cache[id] { return v }
        let v = instance(for: id)?.makeRootView() ?? AnyView(EmptyView())
        cache[id] = v
        return v
    }

    func activateInitial() { activate(selection) }

    /// Switch active plugin: deactivate the previous, activate the next.
    func select(_ id: String) {
        guard id != selection else { return }
        instances[selection]?.deactivate()
        selection = id
        UserDefaults.standard.set(id, forKey: selectionKey)   // restore on next launch
        activate(id)
    }

    private func activate(_ id: String) {
        guard let p = instance(for: id) else { return }
        _ = view(for: id)                      // ensure the view (and view model) exists
        host.clearAttention(for: id)           // selecting a tab clears its badge/banner
        p.activate()
        activated.insert(id)
    }

    /// Reconcile after enable/disable changes: tear down plugins that are no longer
    /// active and fix the selection. Call when the manager's active set changes.
    func reconcile() {
        let active = Set(manager.activeEntries.map(\.id))
        for id in instances.keys where !active.contains(id) {
            instances[id]?.deactivate()
            instances[id] = nil
            cache[id] = nil
            activated.remove(id)
        }
        if !active.contains(selection) {
            selection = manager.activeEntries.first?.id ?? ""
            if !selection.isEmpty { activate(selection) }
        }
        objectWillChange.send()
    }
}
