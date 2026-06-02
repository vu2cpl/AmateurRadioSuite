import SwiftUI
import RadioPluginKit
import RadioPluginUI

/// A searchable quick-switcher: jump to any plugin, or run a command of the active plugin.
/// Opened from the menu / ⌘⇧P.
struct CommandPaletteView: View {
    @ObservedObject var model: SuiteModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.radioTheme) private var theme
    @State private var query = ""

    private enum Action: Identifiable {
        case openPlugin(id: String, title: String, icon: String)
        case runCommand(PluginCommand)
        var id: String {
            switch self {
            case .openPlugin(let id, _, _): return "open:\(id)"
            case .runCommand(let c):        return "cmd:\(c.id)"
            }
        }
    }

    private var actions: [Action] {
        var out: [Action] = model.manager.activeEntries.map {
            .openPlugin(id: $0.id, title: $0.manifest.name, icon: $0.manifest.systemImage)
        }
        // Commands of the currently active plugin.
        if let cmds = model.plugin(for: model.selection)?.menuCommands {
            out += cmds.map { .runCommand($0) }
        }
        guard !query.isEmpty else { return out }
        return out.filter { label(for: $0).localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Go to plugin or run a command…", text: $query)
                    .textFieldStyle(.plain).font(.title3)
                    .onSubmit { runFirst() }
            }
            .padding(12)
            Divider()
            List(actions) { action in
                Button { run(action) } label: {
                    HStack {
                        Image(systemName: icon(for: action)).frame(width: 22).foregroundStyle(theme.accent)
                        Text(label(for: action))
                        Spacer()
                        Text(kind(for: action)).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
        }
        .frame(width: 460, height: 360)
    }

    private func runFirst() { if let first = actions.first { run(first) } }

    private func run(_ action: Action) {
        switch action {
        case .openPlugin(let id, _, _): model.select(id)
        case .runCommand(let c):        c.action()
        }
        dismiss()
    }

    private func label(for a: Action) -> String {
        switch a {
        case .openPlugin(_, let t, _): return t
        case .runCommand(let c):       return c.title
        }
    }
    private func icon(for a: Action) -> String {
        switch a {
        case .openPlugin(_, _, let i): return i
        case .runCommand:              return "command"
        }
    }
    private func kind(for a: Action) -> String {
        switch a { case .openPlugin: return "Plugin"; case .runCommand: return "Command" }
    }
}
