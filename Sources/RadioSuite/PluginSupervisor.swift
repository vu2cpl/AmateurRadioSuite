import Foundation

/// Crash-control for out-of-process (ExtensionKit) plugins. A plugin running in its own
/// process can crash without taking down the host; this supervisor decides what to do
/// when that happens: restart with exponential backoff, and if it crash-loops, quarantine
/// it ("Safe mode for this plugin") so a bad install can't wedge the suite on every launch.
///
/// Pure logic with an injectable clock so it's deterministically testable; the Phase 3
/// `EXHostViewController` hosting drives it from connection-interruption callbacks.
@MainActor
final class PluginSupervisor: ObservableObject {

    /// What the host should do after a crash.
    enum Decision: Equatable {
        case restart(after: TimeInterval)
        case quarantine
    }

    struct Health: Equatable {
        var recentCrashes: [Date] = []
        var restarts: Int = 0
        var quarantined: Bool = false
    }

    @Published private(set) var health: [String: Health] = [:]

    /// Quarantine once this many crashes occur within `window`.
    let crashThreshold: Int
    /// Sliding window for counting crashes toward the threshold.
    let window: TimeInterval
    /// Backoff ceiling.
    let maxBackoff: TimeInterval
    private let clock: () -> Date

    init(crashThreshold: Int = 3, window: TimeInterval = 60,
         maxBackoff: TimeInterval = 30, clock: @escaping () -> Date = Date.init) {
        self.crashThreshold = crashThreshold
        self.window = window
        self.maxBackoff = maxBackoff
        self.clock = clock
    }

    func isQuarantined(_ id: String) -> Bool { health[id]?.quarantined ?? false }

    /// Record a crash and decide what to do. Crashes older than `window` are dropped, so a
    /// plugin that crashes rarely keeps restarting; one that crash-loops gets quarantined.
    @discardableResult
    func recordCrash(_ id: String) -> Decision {
        let now = clock()
        var h = health[id] ?? Health()
        h.recentCrashes.append(now)
        h.recentCrashes = h.recentCrashes.filter { now.timeIntervalSince($0) <= window }

        let decision: Decision
        if h.recentCrashes.count >= crashThreshold {
            h.quarantined = true
            decision = .quarantine
        } else {
            h.restarts += 1
            decision = .restart(after: backoff(forRestart: h.restarts))
        }
        health[id] = h
        return decision
    }

    /// The plugin has run cleanly — reset its restart backoff (kept out of quarantine logic
    /// so a long-lived plugin doesn't accumulate stale restart counts).
    func recordHealthy(_ id: String) {
        guard var h = health[id], !h.quarantined else { return }
        h.restarts = 0
        h.recentCrashes.removeAll()
        health[id] = h
    }

    /// User chose "Try again" on a quarantined plugin — clear its state.
    func clearQuarantine(_ id: String) {
        health[id] = nil
    }

    /// Exponential backoff (1, 2, 4, 8 … capped), restart count is 1-based.
    func backoff(forRestart restart: Int) -> TimeInterval {
        let raw = pow(2.0, Double(max(0, restart - 1)))
        return min(raw, maxBackoff)
    }
}
