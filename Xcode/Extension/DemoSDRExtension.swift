import SwiftUI
import ExtensionFoundation
import ExtensionKit
import RadioPluginKit
import RadioPluginUI

/// Sample out-of-process plugin: a real ExtensionKit `.appex` that the suite discovers and
/// hosts via `EXHostViewController`. Running in its own sandboxed process, a crash here can't
/// take down the suite. This is the reference third-party plugin shape.

struct DemoSDRView: View {
    @Environment(\.radioTheme) private var theme
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 44)).foregroundStyle(theme.accent)
            Text("Demo SDR").font(.title2.weight(.semibold)).foregroundStyle(theme.textPrimary)
            StatusBadge("Out-of-process plugin", kind: .success)
            Text("Hosted by the Amateur Radio Suite via ExtensionKit.")
                .font(.caption).foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(theme.background)
        .radioTheme(.dark)
    }
}

@main
struct DemoSDRExtension: AppExtension {
    var configuration: AppExtensionSceneConfiguration {
        AppExtensionSceneConfiguration(
            PrimitiveAppExtensionScene(id: "primary") { DemoSDRView() }
        )
    }
}
