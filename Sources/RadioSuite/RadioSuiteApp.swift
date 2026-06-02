import SwiftUI
import AppKit
import RadioPluginKit
import RadioPluginUI

@main
struct RadioSuiteApp: App {
    @StateObject private var model = SuiteModel()

    var body: some Scene {
        WindowGroup("Amateur Radio Suite") {
            HostShell(model: model, events: model.host.events, manager: model.manager)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            // Single suite About panel (replaces any per-plugin one).
            CommandGroup(replacing: .appInfo) {
                Button("About Amateur Radio Suite") { showAbout() }
            }
            // Quick switcher.
            CommandGroup(after: .toolbar) {
                Button("Command Palette…") { model.paletteOpen = true }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
            }
            // Commands contributed by the active plugin, routed here.
            CommandMenu("Plugin") {
                ForEach(activeCommands, id: \.id) { cmd in
                    let button = Button(cmd.title) { cmd.action() }
                    if let sc = cmd.shortcut { button.keyboardShortcut(sc) } else { button }
                }
                if activeCommands.isEmpty {
                    Text("No commands for this plugin").disabled(true)
                }
            }
        }

        Settings {
            SettingsHubView(model: model).radioTheme(.dark)
        }
    }

    private var activeCommands: [PluginCommand] {
        model.plugin(for: model.selection)?.menuCommands ?? []
    }

    private func showAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "Amateur Radio Suite",
            .applicationVersion: "1.0",
            .init(rawValue: "Copyright"): "© VU3ESV — hosts radio control apps as plugins.",
        ])
        NSApp.activate(ignoringOtherApps: true)
    }
}
