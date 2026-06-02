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

/// Observable sink for plugin-reported events the host UI renders: a per-plugin
/// inline banner, sidebar/tab badges, and a notification feed.
@MainActor
final class SuiteEvents: ObservableObject {
    /// Inline banner shown above a plugin's pane (latest error/notification).
    @Published var banner: [String: PluginNotification] = [:]
    /// Attention badge per plugin id.
    @Published var badges: [String: PluginBadge] = [:]
    /// Chronological notification feed (for a future notification center).
    @Published var feed: [PluginNotification] = []
}

/// Container-provided services (the plugin "context"). Each plugin gets isolated
/// `UserDefaults` so keys like "serverURL" don't collide between plugins sharing
/// this process, and its reports/notifications are routed to the host UI.
@MainActor
final class SuitePluginHost: PluginHost {
    let events = SuiteEvents()

    func log(_ message: String, plugin: String) {
        print("[\(plugin)] \(message)")
    }

    func defaults(for pluginID: String) -> UserDefaults {
        UserDefaults(suiteName: "suite.\(pluginID)") ?? .standard
    }

    func report(_ error: PluginError, from pluginID: String) {
        log("error[\(error.severity.rawValue)]: \(error.title)", plugin: pluginID)
        let level: PluginNotification.Level = (error.severity == .recoverable) ? .warning : .error
        events.banner[pluginID] = PluginNotification(level: level, title: error.title, body: error.message)
        events.badges[pluginID] = .dot
    }

    func notify(_ notification: PluginNotification, from pluginID: String) {
        log("notify[\(notification.level.rawValue)]: \(notification.title)", plugin: pluginID)
        events.feed.insert(notification, at: 0)
        if notification.level == .warning || notification.level == .error {
            events.banner[pluginID] = notification
            events.badges[pluginID] = .dot
        }
    }

    func setBadge(_ badge: PluginBadge?, for pluginID: String) {
        events.badges[pluginID] = badge
    }

    /// Clear transient attention state when a plugin becomes active.
    func clearAttention(for pluginID: String) {
        events.badges[pluginID] = nil
        events.banner[pluginID] = nil
    }
}
