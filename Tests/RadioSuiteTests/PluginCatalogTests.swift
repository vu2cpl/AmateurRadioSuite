import XCTest
import RadioPluginKit
@testable import RadioSuite

final class PluginCatalogTests: XCTestCase {

    func testCatalogDecode() throws {
        let json = Data("""
        {"name":"T","plugins":[{"id":"com.x.y","name":"Y","latestVersion":"2.0",
        "minHostVersion":"1.0","url":"https://e/y.radioplugin","sha256":"abc","summary":"hi"}]}
        """.utf8)
        let cat = try JSONDecoder().decode(PluginCatalog.self, from: json)
        XCTAssertEqual(cat.plugins.map(\.id), ["com.x.y"])
        XCTAssertEqual(cat.plugins[0].summary, "hi")
    }

    func testInstallStateDetection() {
        let e = CatalogEntry(id: "x", name: "X", latestVersion: "2.0", minHostVersion: "1.0",
                             url: "u", sha256: "s")
        XCTAssertEqual(e.installState(installedVersion: nil), .notInstalled)
        XCTAssertEqual(e.installState(installedVersion: "1.0"), .updateAvailable(installed: "1.0"))
        XCTAssertEqual(e.installState(installedVersion: "2.0"), .upToDate)

        let needsNewer = CatalogEntry(id: "x", name: "X", latestVersion: "2.0",
                                      minHostVersion: "99.0", url: "u", sha256: "s")
        guard case .incompatible = needsNewer.installState(installedVersion: nil) else {
            return XCTFail("expected incompatible")
        }
    }

    @MainActor
    func testCatalogServiceMergesSources() async {
        let json = Data("""
        {"name":"T","plugins":[{"id":"a","name":"A","latestVersion":"1.0",
        "minHostVersion":"1.0","url":"u","sha256":"s"}]}
        """.utf8)
        let store = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let svc = CatalogService(store: store,
                                 defaultSources: [URL(string: "https://x/c.json")!],
                                 fetch: { _ in json })
        await svc.refresh()
        XCTAssertEqual(svc.entries.map(\.id), ["a"])
        XCTAssertNil(svc.lastError)
    }

    @MainActor
    func testCatalogServiceReportsBadSource() async {
        struct Boom: Error {}
        let store = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let svc = CatalogService(store: store,
                                 defaultSources: [URL(string: "https://x/c.json")!],
                                 fetch: { _ in throw Boom() })
        await svc.refresh()
        XCTAssertTrue(svc.entries.isEmpty)
        XCTAssertNotNil(svc.lastError)
    }

    /// Browsed (local) catalog entries show up, persist across launches, and can be removed.
    @MainActor
    func testLocalCatalogEntriesPersistAndMerge() {
        let store = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let svc = CatalogService(store: store)   // no default sources — starts empty
        XCTAssertTrue(svc.entries.isEmpty)

        let e = CatalogEntry(id: "local.x", name: "Local X", latestVersion: "1.0",
                             minHostVersion: "1.0", url: "file:///tmp/x.radioplugin", sha256: "s")
        svc.addLocalEntry(e)
        XCTAssertEqual(svc.entries.map(\.id), ["local.x"])
        XCTAssertTrue(svc.isLocal("local.x"))

        // A fresh service on the same store reloads the persisted local entry.
        let svc2 = CatalogService(store: store)
        XCTAssertEqual(svc2.entries.map(\.id), ["local.x"])

        svc2.removeLocalEntry(id: "local.x")
        XCTAssertTrue(svc2.entries.isEmpty)
        XCTAssertFalse(svc2.isLocal("local.x"))
    }

    /// Build a .radioplugin (zip), install it, reject a bad checksum, then uninstall.
    func testInstallVerifyUninstall() throws {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let payload = work.appendingPathComponent("payload")
        try fm.createDirectory(at: payload, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        let manifest = RadioPluginManifest(id: "com.test.pkg", name: "Pkg", version: "1.0",
                                           isolation: .outOfProcess, capabilities: [.networkClient])
        try JSONEncoder().encode(manifest).write(to: payload.appendingPathComponent("plugin.json"))

        let zip = work.appendingPathComponent("pkg.radioplugin")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        p.arguments = ["-c", "-k", "--sequesterRsrc", payload.path, zip.path]
        try p.run(); p.waitUntilExit()
        XCTAssertEqual(p.terminationStatus, 0)

        let sha = try PackageInstaller.sha256Hex(of: zip)
        let pluginsDir = work.appendingPathComponent("Plugins")

        // Bad checksum is rejected.
        XCTAssertThrowsError(try PackageInstaller.install(localPackage: zip, expectedSHA256: "deadbeef",
                                                          into: pluginsDir))

        // Good install lands the manifest where discovery finds it.
        let installed = try PackageInstaller.install(localPackage: zip, expectedSHA256: sha, into: pluginsDir)
        XCTAssertEqual(installed.id, "com.test.pkg")
        XCTAssertTrue(fm.fileExists(atPath: pluginsDir.appendingPathComponent("com.test.pkg/plugin.json").path))

        // Uninstall removes it.
        try PackageInstaller.uninstall(id: "com.test.pkg", from: pluginsDir)
        XCTAssertFalse(fm.fileExists(atPath: pluginsDir.appendingPathComponent("com.test.pkg").path))
    }
}
