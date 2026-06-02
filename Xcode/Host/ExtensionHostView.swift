import SwiftUI
import ExtensionKit
import ExtensionFoundation
import RadioPluginKit

/// Embeds an out-of-process plugin extension's UI in the suite window via
/// `EXHostViewController`. The extension runs in its own sandboxed process, so a crash
/// stays out of the host (see `PluginSupervisor`).
struct ExtensionHostView: NSViewControllerRepresentable {
    let identity: AppExtensionIdentity
    var sceneID: String = "primary"

    func makeNSViewController(context: Context) -> EXHostViewController {
        let vc = EXHostViewController()
        vc.configuration = .init(appExtension: identity, sceneID: sceneID)
        return vc
    }

    func updateNSViewController(_ vc: EXHostViewController, context: Context) {
        vc.configuration = .init(appExtension: identity, sceneID: sceneID)
    }
}

/// Discovers installed extensions that declare the suite's extension point. Feeds the
/// `PluginManager`'s out-of-process tier (the in-process discovery reads `plugin.json`;
/// this resolves the matching installed `.appex` identities to actually host).
enum ExtensionDiscovery {
    /// First snapshot of currently-installed matching extension identities.
    static func current() async -> [AppExtensionIdentity] {
        do {
            let matching = try AppExtensionIdentity.matching(
                appExtensionPointIDs: RadioExtensionPoint.identifier)
            for await identities in matching { return identities }   // first snapshot
        } catch {
            // No extensions / discovery unavailable — host shows in-process plugins only.
        }
        return []
    }
}
