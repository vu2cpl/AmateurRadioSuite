import SwiftUI
import RadioPluginKit
import RadioPluginUI

/// "Manage Plugins" sheet: lists every discovered plugin (built-in + installed) with
/// its source, status, capabilities, and an enable toggle. Installed plugins appear
/// here without recompiling the container — proving dynamic discovery.
struct PluginManagerView: View {
    @ObservedObject var manager: PluginManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.radioTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            List {
                ForEach(manager.entries) { entry in
                    row(entry)
                }
                if manager.entries.isEmpty {
                    Text("No plugins found.").foregroundStyle(.secondary)
                }
            }
            .listStyle(.inset)
        }
        .frame(width: 560, height: 420)
    }

    private var header: some View {
        HStack {
            Text("Plugins").font(.title2.weight(.semibold))
            Spacer()
            Button {
                manager.reload()
            } label: { Label("Rescan", systemImage: "arrow.clockwise") }
            Button("Open Folder") {
                NSWorkspace.shared.open(InstalledPluginSource.defaultDirectory())
            }
            Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
        }
        .padding()
    }

    @ViewBuilder private func row(_ entry: PluginEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.manifest.systemImage)
                .font(.title2).frame(width: 28)
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.manifest.name).font(.headline)
                    Text("v\(entry.manifest.version)").font(.caption).foregroundStyle(.secondary)
                    sourceTag(entry.sourceKind)
                    statusTag(entry.status)
                }
                if !entry.manifest.capabilities.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(entry.manifest.capabilities, id: \.self) { cap in
                            Text(cap.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { manager.isEnabled(entry.id) },
                set: { manager.setEnabled($0, for: entry.id) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .disabled(isIncompatible(entry))
        }
        .padding(.vertical, 4)
    }

    private func isIncompatible(_ entry: PluginEntry) -> Bool {
        if case .incompatible = entry.status { return true }
        return false
    }

    private func sourceTag(_ kind: PluginSourceKind) -> some View {
        Text(kind == .builtIn ? "Built-in" : kind == .installed ? "Installed" : "Dev")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(theme.surface, in: Capsule())
    }

    @ViewBuilder private func statusTag(_ status: PluginStatus) -> some View {
        switch status {
        case .ready:
            StatusBadge("Ready", kind: .success)
        case .discovered:
            StatusBadge("Out-of-process (soon)", kind: .warning)
        case .incompatible(let reason):
            StatusBadge(reason, kind: .danger)
        }
    }
}
