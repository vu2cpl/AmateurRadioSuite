import XCTest
@testable import RadioSuite

final class StateRestorationTests: XCTestCase {

    @MainActor
    func testRestoresSavedSelectionWhenStillActive() {
        XCTAssertEqual(SuiteModel.restoredSelection(saved: "lp700", active: ["lp100a", "lp700"]), "lp700")
    }

    @MainActor
    func testFallsBackToFirstWhenSavedGone() {
        XCTAssertEqual(SuiteModel.restoredSelection(saved: "removed", active: ["lp100a", "lp700"]), "lp100a")
    }

    @MainActor
    func testFallsBackToFirstWhenNothingSaved() {
        XCTAssertEqual(SuiteModel.restoredSelection(saved: nil, active: ["bpf"]), "bpf")
    }

    @MainActor
    func testEmptyWhenNoPlugins() {
        XCTAssertEqual(SuiteModel.restoredSelection(saved: "x", active: []), "")
    }
}
