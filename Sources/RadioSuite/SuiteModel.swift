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

    @Published var selection: String = ""

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
        let host = self.host
        let supervisor = self.supervisor
        manager = PluginManager(sources: [
            BuiltInPluginSource(host: host),
            InstalledPluginSource(directory: InstalledPluginSource.defaultDirectory()),
        ])
        manager.isQuarantined = { supervisor.isQuarantined($0) }   // quarantined → drop from active
        manager.reload()
        selection = manager.activeEntries.first?.id ?? ""
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
