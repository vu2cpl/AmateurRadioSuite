// Reference skeleton for an out-of-process Radio Suite plugin (ExtensionKit `.appex`).
//
// This is NOT built by the SwiftPM package — it belongs in an Xcode app-extension target
// (SwiftPM cannot produce `.appex` bundles). Add `RadioPluginKit` (1.2+) as a package
// dependency of that target. The exact ExtensionKit scene API is finalized against the SDK
// in Xcode; the shape below shows the intended structure.

import SwiftUI
import ExtensionFoundation
import RadioPluginKit

// MARK: - The extension's UI (ordinary SwiftUI; hosted by the suite via EXHostViewController)

struct DemoSDRView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "dot.radiowaves.left.and.right").font(.largeTitle)
            Text("Demo SDR").font(.headline)
            Text("Running out-of-process as an ExtensionKit plugin.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        // Use RadioPluginUI components + @Environment(\.radioTheme) for a coherent look.
    }
}

// MARK: - Extension entry point

@main
struct DemoSDRExtension: AppExtension {
    // The suite discovers this extension by the point identifier declared in Info.plist
    // (RadioExtensionPoint.identifier). The configuration vends the SwiftUI scene above and
    // wires the typed channel (HostToExtensionMessage / ExtensionToHostMessage) for
    // activate/deactivate/state and report/notify/setBadge.
    var configuration: some AppExtensionConfiguration {
        // e.g. AppExtensionSceneConfiguration { DemoSDRView() }
        // (Filled in against the ExtensionKit SDK in the Xcode target.)
        fatalError("Provide an AppExtensionConfiguration vending DemoSDRView in the Xcode target.")
    }
}
