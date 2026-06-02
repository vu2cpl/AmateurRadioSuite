import SwiftUI
import RadioPluginKit

/// Owns the plugin instances, their cached root views, and the active selection.
/// Views are built once and cached so switching tabs never recreates a plugin's
/// view model or drops its connection.
@MainActor
final class SuiteModel: ObservableObject {
    let host = SuitePluginHost()
    let plugins: [any RadioPlugin]

    @Published var selection: String

    /// Plain, view-friendly description of each plugin for List/TabView.
    struct Entry: Identifiable, Hashable {
        let id: String
        let title: String
        let systemImage: String
    }

    var entries: [Entry] {
        plugins.map {
            let m = type(of: $0).metadata
            return Entry(id: m.id, title: m.title, systemImage: m.systemImage)
        }
    }

    private var cache: [String: AnyView] = [:]
    private var activated: Set<String> = []

    init() {
        let host = self.host
        let plugins = PluginRegistry.all(host: host)
        self.plugins = plugins
        self.selection = plugins.first.map { type(of: $0).metadata.id } ?? ""
    }

    func plugin(for id: String) -> (any RadioPlugin)? {
        plugins.first { type(of: $0).metadata.id == id }
    }

    /// Cached, lazily built root view for a plugin.
    func view(for id: String) -> AnyView {
        if let v = cache[id] { return v }
        let v = plugin(for: id)?.makeRootView() ?? AnyView(EmptyView())
        cache[id] = v
        return v
    }

    /// Activate the initially selected plugin (once, at launch).
    func activateInitial() {
        activate(selection)
    }

    /// Switch active plugin: deactivate the previous, activate the next.
    func select(_ id: String) {
        guard id != selection else { return }
        plugin(for: selection)?.deactivate()
        selection = id
        activate(id)
    }

    private func activate(_ id: String) {
        guard let p = plugin(for: id) else { return }
        // Ensure the view (and its view model) exists before activating.
        _ = view(for: id)
        host.clearAttention(for: id)   // selecting a tab clears its badge/banner
        p.activate()
        activated.insert(id)
    }
}
