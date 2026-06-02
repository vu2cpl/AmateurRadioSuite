import SwiftUI
import RadioPluginKit

/// The suite's unified Settings window: a General pane plus one pane per plugin that
/// provides a `settingsView`.
struct SettingsHubView: View {
    @ObservedObject var model: SuiteModel

    var body: some View {
        TabView {
            GeneralSettingsPane(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }

            ForEach(model.manager.activeEntries) { entry in
                if let settings = model.plugin(for: entry.id)?.settingsView {
                    settings
                        .tabItem { Label(entry.manifest.name, systemImage: entry.manifest.systemImage) }
                }
            }
        }
        .frame(width: 500, height: 380)
    }
}

private struct GeneralSettingsPane: View {
    @ObservedObject var model: SuiteModel
    @AppStorage("suite.layout") private var layout = "sidebar"
    @AppStorage("suite.didOnboard") private var didOnboard = false

    var body: some View {
        Form {
            Picker("Layout", selection: $layout) {
                Text("Sidebar").tag("sidebar")
                Text("Tabs").tag("tabs")
            }
            Toggle("Safe Mode (built-in plugins only)", isOn: Binding(
                get: { model.manager.safeMode },
                set: { model.manager.safeMode = $0 }))

            Section("Maintenance") {
                Button("Show Welcome Again") { didOnboard = false }
                Button("Reset Last-Opened Plugin") {
                    UserDefaults.standard.removeObject(forKey: "suite.lastSelection")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
