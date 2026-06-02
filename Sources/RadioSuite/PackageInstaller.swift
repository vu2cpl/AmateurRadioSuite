import Foundation
import CryptoKit
import RadioPluginKit

/// Installs / removes `.radioplugin` packages (a zip of `plugin.json` + payload) under the
/// suite's plugins directory, where `InstalledPluginSource` discovers them.
///
/// Verified at install: SHA-256 checksum (if provided) and a decodable, host-compatible
/// manifest. NOTE: code-signature / notarization verification is required before *running*
/// an untrusted third-party plugin (the out-of-process ExtensionKit tier) and is deferred
/// until signing infrastructure exists — installs are checksum-verified only for now.
enum PackageInstaller {

    enum InstallError: LocalizedError {
        case checksumMismatch
        case unpackFailed(String)
        case missingManifest
        case incompatible(String)

        var errorDescription: String? {
            switch self {
            case .checksumMismatch:     return "Package checksum did not match the catalog."
            case .unpackFailed(let m):  return "Could not unpack package: \(m)"
            case .missingManifest:      return "Package has no valid plugin.json."
            case .incompatible(let m):  return "Incompatible plugin: \(m)"
            }
        }
    }

    static func sha256Hex(of fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Read a `.radioplugin`'s manifest WITHOUT installing it (unzip to a temp dir, locate and
    /// decode `plugin.json`). Used by the "add plugin from file" catalog flow.
    static func readManifest(fromPackage packageURL: URL) throws -> RadioPluginManifest {
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("radioplugin-read-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        try unzip(packageURL, to: staging)
        let manifestURL = try payloadRoot(in: staging).appendingPathComponent("plugin.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(RadioPluginManifest.self, from: data),
              !manifest.id.isEmpty
        else { throw InstallError.missingManifest }
        return manifest
    }

    /// Install a local `.radioplugin` file into `pluginsDir`. Returns the installed manifest.
    @discardableResult
    static func install(localPackage packageURL: URL,
                        expectedSHA256: String?,
                        into pluginsDir: URL) throws -> RadioPluginManifest {
        // 1. Checksum.
        if let expected = expectedSHA256 {
            let actual = try sha256Hex(of: packageURL)
            guard actual.caseInsensitiveCompare(expected) == .orderedSame else {
                throw InstallError.checksumMismatch
            }
        }

        // 2. Unzip to a temp staging dir.
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("radioplugin-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        try unzip(packageURL, to: staging)

        // 3. Locate the payload root (plugin.json at top, or one level down).
        let root = try payloadRoot(in: staging)

        // 4. Validate manifest.
        let manifestURL = root.appendingPathComponent("plugin.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(RadioPluginManifest.self, from: data),
              !manifest.id.isEmpty
        else { throw InstallError.missingManifest }
        if SemanticVersion.compare(HostInfo.version, manifest.minHostVersion) == .orderedAscending {
            throw InstallError.incompatible("requires host \(manifest.minHostVersion)+")
        }

        // 5. Move into place (replace any existing install of this id).
        let dest = pluginsDir.appendingPathComponent(manifest.id, isDirectory: true)
        try FileManager.default.createDirectory(at: pluginsDir, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: root, to: dest)
        return manifest
    }

    static func uninstall(id: String, from pluginsDir: URL) throws {
        let dir = pluginsDir.appendingPathComponent(id, isDirectory: true)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
    }

    // MARK: - Helpers

    private static func unzip(_ zip: URL, to dest: URL) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        p.arguments = ["-x", "-k", zip.path, dest.path]
        let err = Pipe(); p.standardError = err
        do { try p.run() } catch { throw InstallError.unpackFailed(error.localizedDescription) }
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "ditto failed"
            throw InstallError.unpackFailed(msg)
        }
    }

    /// The directory containing `plugin.json`: the staging root, or its single subdirectory
    /// (zips often wrap content in a top-level folder).
    private static func payloadRoot(in staging: URL) throws -> URL {
        let fm = FileManager.default
        if fm.fileExists(atPath: staging.appendingPathComponent("plugin.json").path) {
            return staging
        }
        let items = (try? fm.contentsOfDirectory(at: staging, includingPropertiesForKeys: [.isDirectoryKey],
                                                 options: [.skipsHiddenFiles])) ?? []
        let dirs = items.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
        if dirs.count == 1,
           fm.fileExists(atPath: dirs[0].appendingPathComponent("plugin.json").path) {
            return dirs[0]
        }
        throw InstallError.missingManifest
    }
}
