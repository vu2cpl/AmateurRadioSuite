import SwiftUI
import AppKit
import RadioPluginKit
import RadioPluginUI

/// The suite's scenes, shared by both entry points: `RadioSuiteApp` (the SwiftPM
/// executable) and the Xcode host's `HostApp`. Keeping the UI here means both render
/// identically; only the Xcode entry additionally wires the out-of-process ExtensionKit
/// layer (via `OutOfProcessHosting`), which the `.task` below invokes if present.
@MainActor
enum SuiteScene {
    @SceneBuilder
    static func make(model: SuiteModel) -> some Scene {
        WindowGroup("Amateur Radio Suite") {
            HostShell(model: model, events: model.host.events, manager: model.manager)
                .frame(minWidth: 900, minHeight: 600)
                .task { await OutOfProcessHosting.bootstrap?(model) }   // nil on plain build
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
                let commands = model.plugin(for: model.selection)?.menuCommands ?? []
                ForEach(commands, id: \.id) { cmd in
                    let button = Button(cmd.title) { cmd.action() }
                    if let sc = cmd.shortcut { button.keyboardShortcut(sc) } else { button }
                }
                if commands.isEmpty {
                    Text("No commands for this plugin").disabled(true)
                }
            }
        }

        Settings {
            SettingsHubView(model: model).radioTheme(.dark)
        }
    }

    private static func showAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "Amateur Radio Suite",
            .applicationVersion: "1.0",
            .init(rawValue: "Copyright"): "© VU3ESV — hosts radio control apps as plugins.",
        ])
        NSApp.activate(ignoringOtherApps: true)
    }
}
