import SwiftUI
import RadioPluginKit

@main
struct RadioSuiteApp: App {
    @StateObject private var model = SuiteModel()

    var body: some Scene {
        WindowGroup("Amateur Radio Suite") {
            HostShell(model: model)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            // Commands contributed by the currently active plugin, routed here.
            CommandMenu("Plugin") {
                ForEach(activeCommands, id: \.id) { cmd in
                    let button = Button(cmd.title) { cmd.action() }
                    if let sc = cmd.shortcut {
                        button.keyboardShortcut(sc)
                    } else {
                        button
                    }
                }
                if activeCommands.isEmpty {
                    Text("No commands for this plugin").disabled(true)
                }
            }
        }
    }

    private var activeCommands: [PluginCommand] {
        model.plugin(for: model.selection)?.menuCommands ?? []
    }
}
