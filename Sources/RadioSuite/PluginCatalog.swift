import Foundation
import RadioPluginKit

/// A catalog index: a list of installable plugins published at a URL (a GitHub-hosted
/// JSON file or a small service). Users can subscribe to multiple catalogs.
struct PluginCatalog: Codable, Sendable {
    var name: String
    var plugins: [CatalogEntry]
}

/// One installable plugin in a catalog. The download is a signed/notarized `.radioplugin`
/// (a zip of `plugin.json` + the `.appex`/payload); `sha256` is the hex digest of that file.
struct CatalogEntry: Codable, Sendable, Identifiable {
    var id: String                 // plugin id (matches RadioPluginManifest.id)
    var name: String
    var latestVersion: String
    var minHostVersion: String
    var url: String                // download URL of the .radioplugin package
    var sha256: String             // hex SHA-256 of the package file
    var systemImage: String?
    var author: String?
    var summary: String?

    enum InstallState: Equatable {
        case notInstalled
        case upToDate
        case updateAvailable(installed: String)
        case incompatible(String)
    }

    /// Compare against what's installed + host compatibility.
    func installState(installedVersion: String?) -> InstallState {
        if SemanticVersion.compare(HostInfo.version, minHostVersion) == .orderedAscending {
            return .incompatible("requires host \(minHostVersion)+")
        }
        guard let installed = installedVersion else { return .notInstalled }
        switch SemanticVersion.compare(installed, latestVersion) {
        case .orderedAscending: return .updateAvailable(installed: installed)
        default:                return .upToDate
        }
    }
}
