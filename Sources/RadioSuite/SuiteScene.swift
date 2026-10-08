import SwiftUI
import AppKit
import RadioPluginKit
import RadioPluginUI

/// The per-app part of UpdateChecker.swift (that file is identical in every
/// VU2CPL app — see its header). Here, not in an entry point, so both
/// `RadioSuiteApp` and the Xcode `HostApp` get it.
extension UpdateChecker.Configuration {
    static let app = UpdateChecker.Configuration(
        repository: "vu2cpl/AmateurRadioSuite", appName: "Amateur Radio Suite")
}

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
                // About 10 s after the first window appears, ask GitHub whether a newer
                // release exists (at most once a day; Settings → General). Later windows
                // and re-appearances are no-ops.
                .task { UpdateChecker.shared.scheduleAutomaticCheck() }
        }
        .commands {
            // Single suite About panel (replaces any per-plugin one), then the update check.
            CommandGroup(replacing: .appInfo) {
                Button("About Amateur Radio Suite") { showAbout() }
                UpdateChecker.CheckButton()
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
