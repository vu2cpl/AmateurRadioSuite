import SwiftUI
import ExtensionFoundation
import RadioPluginKit

/// The Xcode host's implementation of the out-of-process tier. It fills the
/// `OutOfProcessHosting` seam from `Sources/RadioSuite`:
///
///  - as a `PluginSource`, it surfaces installed ExtensionKit `.appex`es (discovered via
///    `AppExtensionIdentity`) as `.discovered` plugin entries — no `plugin.json` required;
///  - as an `OutOfProcessHostProvider`, it renders a matching extension's UI through
///    `ExtensionHostView` (`EXHostViewController`).
///
/// Correlation convention: an entry's `manifest.id` is the extension's **bundle identifier**,
/// which is also the key this provider hosts by — so a discovered entry and an on-disk
/// `plugin.json` whose `id` matches the same bundle id refer to the same plugin.
@MainActor
final class ExtensionHostProvider: OutOfProcessHostProvider {
    static let shared = ExtensionHostProvider()

    /// Installed matching extensions, keyed by bundle identifier.
    private var identities: [String: AppExtensionIdentity] = [:]
    private var sourceInstalled = false

    private init() {}

    // MARK: OutOfProcessHostProvider

    func canHost(_ manifest: RadioPluginManifest) -> Bool {
        identities[manifest.id] != nil
    }

    func makeView(_ manifest: RadioPluginManifest) -> AnyView? {
        identities[manifest.id].map { AnyView(ExtensionHostView(identity: $0)) }
    }

    // MARK: Launch wiring (invoked from SuiteScene's .task via OutOfProcessHosting.bootstrap)

    func bootstrap(_ model: SuiteModel) async {
        if !sourceInstalled {
            model.manager.addSource(ExtensionPluginSource(provider: self))
            sourceInstalled = true
        }
        await refresh()
        model.manager.reload()
        model.reconcile()
    }

    /// Refresh the snapshot of installed matching extensions.
    func refresh() async {
        let found = await ExtensionDiscovery.current()
        identities = Dictionary(found.map { ($0.bundleIdentifier, $0) },
                                uniquingKeysWith: { first, _ in first })
    }

    /// Discovered extensions as plugin entries (read by `ExtensionPluginSource`).
    func entries() -> [PluginEntry] {
        identities.map { bundleID, identity in
            let manifest = RadioPluginManifest(
                id: bundleID,
                name: identity.localizedName,
                version: "—",
                isolation: .outOfProcess,
                systemImage: "puzzlepiece.extension")
            return PluginEntry(manifest: manifest, sourceKind: .installed,
                               status: .discovered, make: nil)
        }
    }
}

/// Surfaces installed ExtensionKit extensions (via `ExtensionHostProvider`) as plugin
/// entries, so they appear in the suite without an on-disk `plugin.json`.
@MainActor
struct ExtensionPluginSource: PluginSource {
    let kind: PluginSourceKind = .installed
    let provider: ExtensionHostProvider
    func discover() -> [PluginEntry] { provider.entries() }
}
