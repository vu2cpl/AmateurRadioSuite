import Foundation
import RadioPluginKit
import LP700App
import LP100AApp
import BandPassFilterController

/// The single edit point for adding/removing a plugin in the static model.
/// To add a plugin: add its package dependency in Package.swift, then add it here.
@MainActor
enum PluginRegistry {
    static func all(host: PluginHost) -> [any RadioPlugin] {
        [
            LP700Plugin(host: host),
            LP100APlugin(host: host),
            BPFPlugin(host: host),
        ]
    }
}

/// Container-provided services. Each plugin gets isolated `UserDefaults` so keys
/// like "serverURL" don't collide between plugins sharing this process.
@MainActor
final class SuitePluginHost: PluginHost {
    func log(_ message: String, plugin: String) {
        print("[\(plugin)] \(message)")
    }

    func defaults(for pluginID: String) -> UserDefaults {
        UserDefaults(suiteName: "suite.\(pluginID)") ?? .standard
    }
}
