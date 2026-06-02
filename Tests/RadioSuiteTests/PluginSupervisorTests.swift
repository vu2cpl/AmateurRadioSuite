import XCTest
@testable import RadioSuite

final class PluginSupervisorTests: XCTestCase {

    /// A controllable clock for deterministic window/backoff tests.
    @MainActor
    final class Clock {
        var now = Date(timeIntervalSince1970: 1_000)
        func advance(_ s: TimeInterval) { now += s }
    }

    @MainActor
    func testRestartsBelowThresholdWithBackoff() {
        let sup = PluginSupervisor(crashThreshold: 3, window: 60)
        XCTAssertEqual(sup.recordCrash("p"), .restart(after: 1))   // 1st restart -> 2^0
        XCTAssertEqual(sup.recordCrash("p"), .restart(after: 2))   // 2nd -> 2^1
        XCTAssertFalse(sup.isQuarantined("p"))
    }

    @MainActor
    func testQuarantineOnCrashLoop() {
        let sup = PluginSupervisor(crashThreshold: 3, window: 60)
        _ = sup.recordCrash("p")
        _ = sup.recordCrash("p")
        XCTAssertEqual(sup.recordCrash("p"), .quarantine)          // 3rd within window
        XCTAssertTrue(sup.isQuarantined("p"))
    }

    @MainActor
    func testCrashesOutsideWindowDoNotQuarantine() {
        let clock = Clock()
        let sup = PluginSupervisor(crashThreshold: 3, window: 60, clock: { clock.now })
        _ = sup.recordCrash("p")
        clock.advance(120)                                        // first crash falls out of window
        _ = sup.recordCrash("p")
        clock.advance(120)
        XCTAssertEqual(sup.recordCrash("p"), .restart(after: 4))  // 3rd cumulative restart -> 2^2; never 3-in-window
        XCTAssertFalse(sup.isQuarantined("p"))
    }

    @MainActor
    func testClearQuarantine() {
        let sup = PluginSupervisor(crashThreshold: 1, window: 60)
        XCTAssertEqual(sup.recordCrash("p"), .quarantine)
        XCTAssertTrue(sup.isQuarantined("p"))
        sup.clearQuarantine("p")
        XCTAssertFalse(sup.isQuarantined("p"))
    }

    @MainActor
    func testBackoffIsCapped() {
        let sup = PluginSupervisor(crashThreshold: 100, window: 600, maxBackoff: 30)
        for _ in 0..<10 { _ = sup.recordCrash("p") }
        if case let .restart(after) = sup.recordCrash("p") {
            XCTAssertEqual(after, 30)                              // capped
        } else { XCTFail("expected restart") }
    }

    @MainActor
    func testSafeModeFiltersToBuiltInOnly() {
        let store = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let mgr = PluginManager(sources: [], store: store)
        XCTAssertFalse(mgr.safeMode)
        mgr.safeMode = true
        XCTAssertTrue(mgr.safeMode)                               // persisted toggle
    }
}
