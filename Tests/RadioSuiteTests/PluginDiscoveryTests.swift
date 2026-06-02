import XCTest
import SwiftUI
import RadioPluginKit
@testable import RadioSuite

final class PluginDiscoveryTests: XCTestCase {

    /// An installed plugin is discovered from its plugin.json — no recompile, no code load.
    @MainActor
    func testInstalledDiscoveryReadsManifest() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let pdir = tmp.appendingPathComponent("com.example.demosdr")
        try FileManager.default.createDirectory(at: pdir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let manifest = RadioPluginManifest(
            id: "com.example.demosdr", name: "Demo SDR", version: "2.0",
            isolation: .outOfProcess,
            capabilities: [.networkClient, .notifications],
            systemImage: "dot.radiowaves.left.and.right", author: "Example")
        try JSONEncoder().encode(manifest).write(to: pdir.appendingPathComponent("plugin.json"))

        let entries = InstalledPluginSource(directory: tmp).discover()
        XCTAssertEqual(entries.count, 1)
        let e = try XCTUnwrap(entries.first)
        XCTAssertEqual(e.id, "com.example.demosdr")
        XCTAssertEqual(e.manifest.capabilities, [.networkClient, .notifications])
        XCTAssertEqual(e.sourceKind, .installed)
        XCTAssertEqual(e.status, .discovered)
        XCTAssertFalse(e.isRunnable)            // installed runs out-of-process (Phase 3)
    }

    @MainActor
    func testIncompatibleHostVersionIsRejected() {
        let m = RadioPluginManifest(id: "x", name: "X", version: "1.0",
                                    minHostVersion: "99.0", isolation: .outOfProcess)
        guard case .incompatible = InstalledPluginSource.status(for: m) else {
            return XCTFail("expected .incompatible for minHostVersion 99.0")
        }
    }

    func testSemanticVersionCompare() {
        XCTAssertEqual(SemanticVersion.compare("1.2", "1.10"), .orderedAscending)
        XCTAssertEqual(SemanticVersion.compare("1.0", "1.0"), .orderedSame)
        XCTAssertEqual(SemanticVersion.compare("2.0", "1.9"), .orderedDescending)
    }

    @MainActor
    func testManagerMergeEnableDisable() {
        let store = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let mgr = PluginManager(sources: [StubSource()], store: store)
        mgr.reload()
        XCTAssertEqual(mgr.activeEntries.map(\.id), ["stub"])

        mgr.setEnabled(false, for: "stub")
        XCTAssertTrue(mgr.activeEntries.isEmpty, "disabled plugin should drop out of active set")

        mgr.setEnabled(true, for: "stub")
        XCTAssertEqual(mgr.activeEntries.count, 1)
    }
}

// MARK: - Test doubles

@MainActor
private final class StubPlugin: RadioPlugin {
    static let manifest: RadioPluginManifest? = RadioPluginManifest(
        id: "stub", name: "Stub", version: "1.0", isolation: .inProcess)
    static var metadata: PluginMetadata { manifest!.metadata }
    init(host: PluginHost) {}
    func makeRootView() -> AnyView { AnyView(EmptyView()) }
}

@MainActor
private struct StubSource: PluginSource {
    let kind: PluginSourceKind = .builtIn
    func discover() -> [PluginEntry] {
        [PluginEntry(manifest: StubPlugin.manifest!, sourceKind: .builtIn,
                     status: .ready, make: { StubPlugin(host: SuitePluginHost()) })]
    }
}
