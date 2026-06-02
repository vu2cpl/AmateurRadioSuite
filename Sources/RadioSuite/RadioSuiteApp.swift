import SwiftUI

/// Entry point for the plain SwiftPM build (`swift build` / build-app.sh). This build
/// links only RadioPluginKit and runs no out-of-process layer, so installed plugins are
/// discovered but not hosted. The Xcode host target uses its own `HostApp` entry (which
/// adds the ExtensionKit hosting) and excludes this file; both render `SuiteScene`.
@main
struct RadioSuiteApp: App {
    @StateObject private var model = SuiteModel()

    var body: some Scene {
        SuiteScene.make(model: model)
    }
}
